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
            map<anydata> dataMap = {[OPERATION_TYPE] : operationNode.getKind(), [PATH] : path};
            data = <Data>self.visitSelections(operationNode.getSelections(), dataMap.cloneReadOnly());
        }
        return self.getOutput(data);
    }

    isolated function visitSelections(parser:SelectionNode[] selections, anydata data) returns anydata {
        Data dataRecord = {};
        foreach parser:SelectionNode selection in selections {
            if selection is parser:FieldNode {
                parser:RootOperationType operationType = self.getOperationTypeFromData(data);
                string[] path = self.getSelectionPathFromData(data);
                path.push(selection.getName());
                map<anydata> dataMap = {[OPERATION_TYPE] : operationType, [PATH] : path};
                dataRecord[selection.getAlias()] = self.visitField(selection, dataMap);
            } else if selection is parser:FragmentNode {
                Data fragmentData = <Data>self.visitFragment(selection, data);
                foreach [string, anydata] [key, value] in fragmentData.entries() {
                    dataRecord[key] = value;
                }
            }
        }
        return dataRecord;
    }

    public isolated function visitField(parser:FieldNode fieldNode, anydata data = ()) returns anydata {
        parser:RootOperationType operationType = self.getOperationTypeFromData(data);
        boolean isIntrospection = true;
        anydata result = "";
        if fieldNode.getName() == SCHEMA_FIELD {
            IntrospectionExecutor introspectionExecutor = new(self.schema);
            result = introspectionExecutor.getSchemaIntrospection(fieldNode);
        } else if fieldNode.getName() == TYPE_FIELD {
            IntrospectionExecutor introspectionExecutor = new(self.schema);
            result = introspectionExecutor.getTypeIntrospection(fieldNode);
        } else if fieldNode.getName() == TYPE_NAME_FIELD {
            if operationType == parser:OPERATION_QUERY {
                result = QUERY_TYPE_NAME;
            } else if operationType == parser:OPERATION_MUTATION {
                result = MUTATION_TYPE_NAME;
            } else {
                result = SUBSCRIPTION_TYPE_NAME;
            }
        } else {
            isIntrospection = false;
        }
        if !isIntrospection {
            return self.resolve(fieldNode, operationType);
        }
        return result;
    }

    public isolated function visitFragment(parser:FragmentNode fragmentNode, anydata data = ()) returns anydata {
        parser:RootOperationType operationType = self.getOperationTypeFromData(data);
        string[] path = self.getSelectionPathFromData(data);
        if operationType != parser:OPERATION_MUTATION {
            map<anydata> updatedData = {[OPERATION_TYPE] : operationType, [PATH] : path};
            return self.visitSelectionsParallelly(fragmentNode, updatedData.cloneReadOnly());
        }
        Data dataMap = <Data>self.visitSelections(fragmentNode.getSelections(), data);
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
        string[] path = self.getSelectionPathFromData(data);
        Data dataRecord = {};
        [parser:FieldNode, future<anydata>][] selectionFutures = [];
        foreach parser:SelectionNode selection in selectionParentNode.getSelections() {
            if selection is parser:FieldNode {
                path.push(selection.getName());
                map<anydata> dataMap = {[OPERATION_TYPE] : operationType, [PATH] : path};
                future<anydata> 'future = start self.visitField(selection, dataMap.cloneReadOnly());
                selectionFutures.push([selection, 'future]);
            } else if selection is parser:FragmentNode {
                Data fragmentData = <Data>self.visitSelectionsParallelly(selection, data);
                foreach [string, anydata] [key, value] in fragmentData.entries() {
                    dataRecord[key] = value;
                }
            }
        }
        foreach [parser:SelectionNode, future<anydata>] [selection, 'future] in selectionFutures {
            anydata|error result = wait 'future;
            if result is anydata {
                dataRecord[selection.getAlias()] = result;
                continue;
            } else {
                path.push(selection.getName());
                dataRecord[selection.getAlias()] = ();
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
        return dataRecord;
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
