# ConcurrencyCompatibility

Tools for using Swift Concurrency on macOS 10.15 Catalina, iOS 13, tvOS 13, and watchOS 6.

Xcode 13.2 adds backwards deployment of Swift Concurrency to targets earlier than macOS 12.0 Monterey, iOS 15, tvOS 15, and watchOS 8.
This includes all parts of the Swift Concurrency standard library, but does not include additions to Apple's frameworks to support Swift Concurrency outside of automatic bridging for Objective-C methods.
This package aims to provide alternatives to those additions where possible.
