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

import graphql.dataloader;

import ballerina/http;
import ballerina/jballerina.java;
import ballerina/lang.value;

# The GraphQL context object used to pass the meta information between resolvers.
public isolated class Context {
    private Engine? engine = ();
    private boolean hasFileInfo = false; // This field value changed by setFileInfo method

    public isolated function init() {
        self.intializeContext();
    }

    # Sets a given value for a given key in the GraphQL context.
    #
    # + key - The key for the value to be set
    # + value - Value to be set
    public isolated function set(string 'key, value:Cloneable|isolated object {} value) {
        if value is value:Cloneable {
            self.setAttribute('key, value.clone());
        } else {
            self.setAttribute('key, value);
        }
    }

    isolated function setAttribute(string uuid, value:Cloneable|isolated object {} value) = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    # Retrieves a value using the given key from the GraphQL context.
    #
    # + key - The key corresponding to the required value
    # + return - The value if the key is present in the context, a `graphql:Error` otherwise
    public isolated function get(string 'key) returns value:Cloneable|isolated object {}|Error {
        value:Cloneable|isolated object {}? value = self.getAttribute('key);
        if value is () {
            return error Error(string`Attribute with the key "${'key}" not found in the context`);
        } else if value is value:Cloneable {
            return value.clone();
        } else {
            return value;
        }
    }

    isolated function getAttribute(string uuid) returns value:Cloneable|isolated object {}? = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    # Removes a value using the given key from the GraphQL context.
    #
    # + key - The key corresponding to the value to be removed
    # + return - The value if the key is present in the context, a `graphql:Error` otherwise
    public isolated function remove(string 'key) returns value:Cloneable|isolated object {}|Error {
        value:Cloneable|isolated object {}? value = self.removeAttribute('key);
        if value is () {
            return error Error(string`Attribute with the key "${'key}" not found in the context`);
        } else if value is value:Cloneable {
            return value.clone();
        } else {
            return value;
        }
    }

    isolated function removeAttribute(string uuid) returns value:Cloneable|isolated object {}? = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    # Register a given DataLoader instance for a given key in the GraphQL context.
    #
    # + key - The key for the DataLoader to be registered
    # + dataloader - The DataLoader instance to be registered
    public isolated function registerDataLoader(string key, dataloader:DataLoader dataloader) = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    # Retrieves a DataLoader instance using the given key from the GraphQL context.
    #
    # + key - The key corresponding to the required DataLoader instance
    # + return - The DataLoader instance if the key is present in the context otherwise panics
    public isolated function getDataLoader(string key) returns dataloader:DataLoader = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    # Remove cache entries related to the given path.
    #
    # + path - The path corresponding to the cache entries to be removed (Ex: "person.address.city")
    # + return - The error if the cache invalidateion fails or nil otherwise
    public isolated function invalidate(string path) returns error? {
        Engine? engine = self.getEngine();
        if engine is Engine {
            return engine.invalidate(path);
        }
        return;
    }

    # Remove all cache entries.
    #
    # + return - The error if the cache invalidateion fails or nil otherwise
    public isolated function invalidateAll() returns error? {
        Engine? engine = self.getEngine();
        if engine is Engine {
            return engine.invalidateAll();
        }
        return;
    }

    isolated function addError(ErrorDetail err) = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    isolated function addErrors(ErrorDetail[] errs) = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    isolated function getErrors() returns ErrorDetail[] = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    isolated function setFileInfo(map<Upload|Upload[]> fileInfo) = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.EngineUtils"
    } external;

    isolated function getFileInfo() returns map<Upload|Upload[]> = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.EngineUtils"
    } external;

    public isolated function resolve(Field 'field) returns anydata {
        Engine? engine = self.getEngine();
        if engine is Engine {
            return engine.resolve(self, 'field, false);
        }
        return;
    }

    isolated function setEngine(Engine engine) {
        lock {
            self.engine = engine;
        }
    }

    isolated function getEngine() returns Engine? {
        lock {
            return self.engine;
        }
    }

    isolated function resetErrors() = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    isolated function resolvePlaceholders() {
        self.dispatchDataloaders();
        Placeholder[] unResolvedPlaceholders = self.getUnresolvedPlaceholders();
        self.removeAllUnresolvedPlaceholders();
        [Placeholder, future<anydata>][] placeholderValues = [];
        foreach Placeholder placeholder in unResolvedPlaceholders {
            Engine? engine = self.getEngine();
            if engine is () {
                continue;
            }
            future<anydata> resolvedValue = start engine.resolve(self, placeholder.getField(), false);
            placeholderValues.push([placeholder, resolvedValue]);
        }
        foreach [Placeholder, future<anydata>] [placeholder, 'future] in placeholderValues {
            anydata|error resolvedValue = wait 'future;
            if resolvedValue is error {
                ErrorDetail errorDetail = {
                    message: resolvedValue.message()
                };
                self.addError(errorDetail);
                self.decrementUnresolvedPlaceholderCount();
                continue;
            }
            placeholder.setValue(resolvedValue);
            self.decrementUnresolvedPlaceholderCount();
        }
    }

    isolated function dispatchDataloaders() {
        string[] nonDispatchedDataLoaderIds = self.getDataloaderIds();
        future<()>[] dataloaders = [];
        foreach string dataLoaderId in nonDispatchedDataLoaderIds {
            dataloader:DataLoader dataloader = self.getDataLoader(dataLoaderId);
            future<()> 'future = start dataloader.dispatch();
            dataloaders.push('future);
        }
        foreach future<()> 'future in dataloaders {
            error? err = wait 'future;
            if err is error {
                ErrorDetail errorDetail = {
                    message: err.message()
                };
                self.addError(errorDetail);
                continue;
            }
        }
    }

    isolated function addUnresolvedPlaceholder(string uuid, Placeholder placeholder) = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    isolated function intializeContext() = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    isolated function getPlaceholderValue(string uuid) returns anydata {
        Placeholder placeholder = self.getPlaceholder(uuid);
        return placeholder.getValue();
    }

    isolated function getPlaceholder(string uuid) returns Placeholder = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    isolated function getUnresolvedPlaceholderCount() returns int = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    isolated function getUnresolvedPlaceholderNodeCount() returns int = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    isolated function decrementUnresolvedPlaceholderNodeCount() = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    isolated function hasPlaceholders() returns boolean = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    isolated function clearDataLoadersCachesAndPlaceholders() {
        // This function is called at the end of each subscription loop execution to prevent using old values
        // from DataLoader caches in the next iteration and to avoid filling up the idPlaceholderMap.
        string[] nonDispatchedDataLoaderIds = self.getDataloaderIds();
        foreach string dataLoaderId in nonDispatchedDataLoaderIds {
            self.getDataLoader(dataLoaderId).clearAll();
        }
        self.clearPlaceholders();
    }

    isolated function clearPlaceholders() = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    isolated function getDataloaderIds() returns string[] = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    isolated function getUnresolvedPlaceholders() returns Placeholder[] = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    isolated function removeAllUnresolvedPlaceholders() = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;

    isolated function decrementUnresolvedPlaceholderCount() = @java:Method {
        'class: "io.dimuthu.stdlib.graphql.runtime.engine.Context"
    } external;
}

isolated function initDefaultContext(http:RequestContext requestContext, http:Request request) returns Context|error {
    return new;
}
