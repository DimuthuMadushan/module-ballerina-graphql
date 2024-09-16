// Copyright (c) 2023 WSO2 LLC. (http://www.wso2.com) All Rights Reserved.
//
// WSO2 LLC. licenses this file to you under the Apache License,
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

service on new graphql:Listener(4000) {
    resource function get _entities() returns string {
        return "Entities";
    }

    resource function subscribe _service() returns stream<string> {
        return ["stream"].toStream();
    }
}

service on new graphql:Listener(4000) {
    resource function get greet() returns string {
        return "Hi!";
    }

    remote function _entities() returns string {
        return "Entities";
    }
}
