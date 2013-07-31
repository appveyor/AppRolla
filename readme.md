## Introduction

AppRoller is PowerShell library for deploying complex .NET applications to multiple servers in parallel. It was originally developed to provide deployment functionality for [AppVeyor](http://www.appveyor.com) - cloud-based continuous integration for .NET developers.

## Design principles

- Agent-less deployment with remote PowerShell.
- Get the best parts from Capistrano, but don't try to mimic it. Provide native PowerShell experience.
- Application artifacts are stored in AppVeyor cloud storage
