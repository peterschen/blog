---
title: Run Visual Studio Test task in 64bit
url: /run-visual-studio-test-task-in-64bit
date: 2019-05-29T11:26:37.000Z
tags: [azure-devops, azure-pipelines, visual-studio, testing]
---

All of our managed assemblies are build with the `any cpu` target and we can use both the 32-bit and 64-bit task runner of Azure Pipelines.

One of our projects uses a C++ DLL that is either in 32-bit or 64-bit and we need a specific test runner (the 64-bit one to be exact) to not fail with a `System.BadImageFormatExeption`.

By default the Visual Studio test runner will start a 32-bit process. If you need to use the 64-bit version you need to specify extra arguments with supplying `otherConsoleOptions` to the task:

```yaml
- task: VSTest@2
  displayName: Run tests
  inputs:
    testAssemblyVer2: |
      **\bin\$(BuildConfiguration)\**\*Test.dll
      !**\obj\**
      !**\xunit.runner.visualstudio.testadapter.dll
      !**\xunit.runner.visualstudio.dotnetcore.testadapter.dll
    runTestsInIsolation: true
    codeCoverageEnabled: true
    otherConsoleOptions: '/Platform:x64'
```

**Note:** [The Visual Studio Test task](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/test/vstest?view=azure-devops#arguments) sports a parameter called `platform`[which **does not** change the architecture of the test runner executable](https://github.com/Microsoft/azure-pipelines-tasks/issues/1252#issuecomment-185673083).
