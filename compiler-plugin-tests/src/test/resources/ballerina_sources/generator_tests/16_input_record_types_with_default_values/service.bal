// Copyright (c) 2022 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

# Represents a Person
#
# + name - Name of the person
# + age - age of the person
# + address - Addres of the person
type Person record {
    string name = "Walter";
    int age;
    Address address;
};

# Represents an address.
#
# + number - The number of the address
# + street - The street of the address
# + city - The city of the address
type Address record {
    int number;
    string street;
    string city = "Albuquerque";
};

isolated service on new graphql:Listener(9000) {

    isolated resource function get city(Person person) returns string {
        return person.address.city;
    }
}
