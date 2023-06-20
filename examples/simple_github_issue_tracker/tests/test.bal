import ballerina/http;
import ballerina/test;

@test:Config {
    groups: ["query"],
    enable: true
}
function testUser() returns error? {
    string query = "query { user { login } }";
    json expectedResult = {
        "data": {
            "user": {
                "login": owner
            }
        }
    };
    json actualResult = check testClient->execute(query);
    test:assertEquals(expectedResult, actualResult, "Invalid user name");
}

@test:Config {
    groups: ["query"],
    enable: true
}
function testRepositories() returns error? {
    string query = "query { repositories { name }}";
    json jsonResponse = check testClient->execute(query);
    test:assertTrue(jsonResponse is map<json>, "Invalid response type");
    map<json> actualResult = check jsonResponse.ensureType();
    test:assertTrue(actualResult.hasKey("data"));
    test:assertFalse(actualResult.hasKey("errors"));
}

@test:Config {
    groups: ["query"],
    enable: true
}
function testRepository() returns error? {
    string repoName = "Module-Ballerina-GraphQL";
    string query = string `query { repository(repositoryName: "${repoName}"){ defaultBranch } }`;
    json expectedResult = {
        "data": {
            "repository": {
                "defaultBranch": "master"
            }
        }
    };
    json actualResult = check testClient->execute(query);
    test:assertEquals(actualResult, expectedResult);
}

@test:Config {
    groups: ["query"],
    enable: true
}
function testBranches() returns error? {
    string repoName = "Module-Ballerina-GraphQL";
    string username = "gqlUser";
    string query = string `query { branches(repositoryName: "${repoName}", perPageCount: 10, username: "${username}"){ name } }`;
    json expectedResult = {
        "data": {
            "branches": [
                {
                    "name": "master"
                }
            ]
        }
    };
    json actualResult = check testClient->execute(query);
    test:assertEquals(expectedResult, actualResult);
}

@test:Config {
    groups: ["mutation"],
    enable: true
}
function createRepository() returns error? {
    string repoName = "Test-Repo";
    string query = string `mutation {createRepository(createRepoInput: {name: "${repoName}"}) {name} }`;
    json expectedResult = {
        "errors":[
            {
                "message":"Unprocessable Entity",
                "locations":[
                    {
                        "line":1,
                        "column":11
                    }
                ],
            "path":["createRepository"]
            }
        ],
        "data": null
    };
    json actualResult = check testClient->execute(query);
    test:assertEquals(expectedResult, actualResult);
}

@test:Mock {
    functionName: "initRestClient"
}
function initMockRestClient() returns http:Client|error => test:mock(http:Client);

@test:Config {
    groups: ["mutation"],
    enable: false
}
function createRepositoryWithMockClient() returns error? {
    string repoName = "Test-Repo";
    string query = string `mutation {createRepository(createRepoInput: {name: "${repoName}"}) {name} }`;
    GitHubRepository expectedResult = {
        id: 1,
        name: repoName,
        'fork: false,
        created_at: "2020-10-10T10:10:10Z",
        updated_at: "2020-10-10T10:10:10Z",
        language: "Ballerina",
        has_issues: false,
        forks_count: 5,
        open_issues_count: 9,
        visibility: "Public",
        forks: 7,
        open_issues: 3,
        watchers: 55,
        default_branch: "master"
    };
    test:prepare(githubRestClient).when("post").withArguments(["/user/repos", {name: repoName}]).thenReturn(expectedResult);
    json actualResult = check testClient->execute(query);
    test:assertEquals(expectedResult, actualResult);
}
