// Copyright (c) 2021 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import dimuthu/graphql;
import test_package.types as types;

service graphql:Service on new graphql:Listener(4000) {
    resource function get greet(json name) returns string {
        return "Hello";
    }
}

service graphql:Service on new graphql:Listener(4000) {
    resource function get greet(map<string> name) returns string {
        return "Hello";
    }
}

service graphql:Service on new graphql:Listener(4000) {
    resource function get greet(byte[] name) returns string {
        return "Hello";
    }
}

const RED = "RED";
const GREEN = "GREEN";
const BLUE = "BLUE";
type Color RED|GREEN|BLUE;

service graphql:Service on new graphql:Listener(4000) {
    resource function get color(Color color) returns string {
        return "Hello, world";
    }
}

service graphql:Service on new graphql:Listener(4000) {
    resource function get greet(int age, byte[] name) returns string {
        return "Hello";
    }
}

service graphql:Service on new graphql:Listener(4000) {
    resource function get greet(any name) returns string {
        return "Hello";
    }
}

service graphql:Service on new graphql:Listener(4000) {
    resource function get greet(anydata name) returns string {
        return "Hello";
    }
}

service on new graphql:Listener(4000) {
    resource function get greet(types:Headers headers) returns string {
        return "Hello";
    }
}

service on new graphql:Listener(4000) {
    resource function get greet(types:Service 'service) returns string {
        return "Hello";
    }
}
