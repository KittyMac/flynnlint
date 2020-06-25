//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
import LanguageServerProtocol

private let requestTypes: [_RequestType.Type] = [
  BuildTargets.self,
  BuildTargetOutputPaths.self,
  BuildTargetSources.self,
  InitializeBuild.self,
  RegisterForChanges.self,
  ShutdownBuild.self,
  SourceKitOptions.self
]

private let notificationTypes: [NotificationType.Type] = [
  BuildTargetsChangedNotification.self,
  ExitBuildNotification.self,
  FileOptionsChangedNotification.self,
  InitializedBuildNotification.self
]

public let bspRegistry = MessageRegistry(requests: requestTypes, notifications: notificationTypes)
