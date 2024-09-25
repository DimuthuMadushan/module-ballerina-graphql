// Copyright (c) 2020, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import graphql.parser;
import ballerina/jballerina.java;

isolated class Executor {

    private final readonly & __Schema schema;
    private final Engine engine; // This field needed to be accessed from the native code
    private final Context context;
    private any|error result; // The value of this field is set using setResult method

    isolated function init(Engine engine, readonly & __Schema schema, Context context, any|error result = ()) {
        self.engine = engine;
        self.schema = schema;
        self.context = context;
        self.result = ();
        self.setResult(result);
        self.initializeDataMap();
    }

    isolated function initializeDataMap() = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.ExecutorVisitor"
    } external;

    isolated function execute(parser:OperationNode operationNode) returns OutputObject {
        string[] path = [];
        if operationNode.getName() != parser:ANONYMOUS_OPERATION {
            path.push(operationNode.getName());
        }
        Engine engine;
        lock {
            engine = self.engine;
        }
        Data data = {};
        service object {} serviceObject = engine.getService();
        if operationNode.getKind() != parser:OPERATION_MUTATION && serviceObject is isolated service object {} {
            map<anydata> dataMap = {[OPERATION_TYPE] : operationNode.getKind(), [PATH] : path};
            data = <Data>self.visitSelectionsParallelly(operationNode, dataMap.cloneReadOnly());
        } else {
            foreach parser:SelectionNode selection in operationNode.getSelections() {
                if selection is parser:FieldNode {
                    path.push(selection.getName());
                }
                map<anydata> dataMap = {[OPERATION_TYPE] : operationNode.getKind(), [PATH] : path};
                Data selectionData = <Data>self.visitSelection(selection, dataMap);
                foreach [string, anydata] [key, value] in selectionData.entries() {
                    data[key] = value;
                }
            }
        }
        return self.getOutput(data);
    }

    isolated function visitSelection(parser:SelectionNode selection, anydata data) returns anydata {
        if selection is parser:FieldNode {
            return self.visitField(selection, data);
        } else if selection is parser:FragmentNode {
            return self.visitFragment(selection, data);
        }
    }

    public isolated function visitField(parser:FieldNode fieldNode, anydata data = ()) returns anydata {
        parser:RootOperationType operationType = self.getOperationTypeFromData(data);
        boolean isIntrospection = true;
        Data dataMap = {};
        if fieldNode.getName() == SCHEMA_FIELD {
            IntrospectionExecutor introspectionExecutor = new(self.schema);
            dataMap[fieldNode.getAlias()] = introspectionExecutor.getSchemaIntrospection(fieldNode);
        } else if fieldNode.getName() == TYPE_FIELD {
            IntrospectionExecutor introspectionExecutor = new(self.schema);
            dataMap[fieldNode.getAlias()] = introspectionExecutor.getTypeIntrospection(fieldNode);
        } else if fieldNode.getName() == TYPE_NAME_FIELD {
            if operationType == parser:OPERATION_QUERY {
                dataMap[fieldNode.getAlias()] = QUERY_TYPE_NAME;
            } else if operationType == parser:OPERATION_MUTATION {
                dataMap[fieldNode.getAlias()] = MUTATION_TYPE_NAME;
            } else {
                dataMap[fieldNode.getAlias()] = SUBSCRIPTION_TYPE_NAME;
            }
        } else {
            isIntrospection = false;
        }
        if !isIntrospection {
            dataMap[fieldNode.getAlias()]  = self.resolve(fieldNode, operationType);
        }
        return dataMap;
    }

    public isolated function visitFragment(parser:FragmentNode fragmentNode, anydata data = ()) returns anydata {
        parser:RootOperationType operationType = self.getOperationTypeFromData(data);
        string[] path = self.getSelectionPathFromData(data);
        if operationType != parser:OPERATION_MUTATION {
            map<anydata> updatedData = {[OPERATION_TYPE] : operationType, [PATH] : path};
            return self.visitSelectionsParallelly(fragmentNode, updatedData.cloneReadOnly());
        }
        Data dataMap = {};
        foreach parser:SelectionNode selection in fragmentNode.getSelections() {
            if selection is parser:FieldNode {
                path.push(selection.getName());
                map<anydata> updatedData = {[OPERATION_TYPE] : operationType, [PATH] : path};
                Data fieldData = <Data>self.visitField(selection, updatedData);
                foreach [string, anydata] [key, value] in fieldData.entries() {
                    dataMap[key] = value;
                }
            } else if selection is parser:FragmentNode {
                map<anydata> updatedData = {[OPERATION_TYPE] : operationType, [PATH] : path};
                Data fragmentData = <Data>self.visitFragment(selection, updatedData);
                foreach [string, anydata] [key, value] in fragmentData.entries() {
                    dataMap[key] = value;
                }
            }
        }
        return dataMap;
    }

    isolated function resolve(parser:FieldNode fieldNode, parser:RootOperationType operationType) returns anydata {
        __Schema schema = self.schema;
        any|error result;
        Engine engine;
        Context context;
        lock {
            result = self.getResult();
            engine = self.engine;
            context = self.context;
        }
        Field 'field = getFieldObject(fieldNode, operationType, schema, engine, result);

        anydata resolvedResult = engine.resolve(context, 'field);
        return resolvedResult is ErrorDetail ? () : resolvedResult;
    }

    isolated function getOutput(Data data) returns OutputObject {
        Context context;
        lock {
            context = self.context;
        }
        ErrorDetail[] errors = context.getErrors();
        if !self.context.hasPlaceholders() {
            // Avoid rebuilding the value tree if there are no place holders
            return getOutputObject(data, errors);
        }
        ValueTreeBuilder valueTreeBuilder = new ();
        Data dataTree = valueTreeBuilder.build(context, data);
        errors = context.getErrors();
        return getOutputObject(dataTree, errors);
    }

    private isolated function getSelectionPathFromData(anydata data) returns string[] {
        map<anydata> dataMap = <map<anydata>>data;
        string[] path = <string[]>dataMap[PATH];
        return [...path];
    }

    private isolated function getOperationTypeFromData(anydata data) returns parser:RootOperationType {
        map<anydata> dataMap = <map<anydata>>data;
        return <parser:RootOperationType>dataMap[OPERATION_TYPE];
    }

    private isolated function visitSelectionsParallelly(parser:SelectionParentNode selectionParentNode,
            readonly & anydata data = ()) returns anydata {
        parser:RootOperationType operationType = self.getOperationTypeFromData(data);
        [parser:SelectionNode, future<anydata>][] selectionFutures = [];
        string[] path = self.getSelectionPathFromData(data);
        Data dataMap = {};
        foreach parser:SelectionNode selection in selectionParentNode.getSelections() {
            if selection is parser:FieldNode {
                path.push(selection.getName());
            }
            map<anydata> updatedData = {[OPERATION_TYPE] : operationType, [PATH] : path};
            future<anydata> 'future = start self.visitSelection(selection, updatedData.cloneReadOnly());
            selectionFutures.push([selection, 'future]);
        }
        foreach [parser:SelectionNode, future<anydata>] [selection, 'future] in selectionFutures {
            anydata|error result = wait 'future;
            if result is anydata {
                foreach [string, anydata] [key, value] in (<Data>result).entries() {
                    dataMap[key] = value;
                }
                continue;
            }
            if selection is parser:FieldNode {
                path.push(selection.getName());
                dataMap[selection.getAlias()] = ();
                ErrorDetail errorDetail = {
                    message: result.message(),
                    locations: [selection.getLocation()],
                    path: path
                };
                lock {
                    self.context.addError(errorDetail);
                }
            }
        }
        return dataMap;
    }

    private isolated function setResult(any|error result) = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.EngineUtils"
    } external;

    private isolated function getResult() returns any|error = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.EngineUtils"
    } external;

    private isolated function addData(string key, anydata value) = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.ExecutorVisitor"
    } external;

    private isolated function getDataMap() returns Data = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.ExecutorVisitor"
    } external;
}
