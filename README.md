DCXMPP
======

XMPP over BOSH library for iOS or OSX in objective-c. This library implements [XEP-0206: XMPP Over BOSH](http://xmpp.org/extensions/xep-0206.html). This is similar to how [strophe.js](https://github.com/strophe/strophejs) library works. 

Besides the normal core standard BOSH/XMPP support, other notable supported standards are:
XEP-0045. Commonly know as group chat.
XEP-0085. Commonly know as "isTyping" messages 

# Examples #

```objective-c 
some wonderful example on how to use the library
```

# Requirements/Dependencies  #

The only required dependency is XMLKit. CocoaPods will automatically manage this dependency if you choose to use it.

https://github.com/daltoniam/XMLKit

# Install #

The recommended approach for installing DCXMPP is via the CocoaPods package manager, as it provides flexible dependency management and dead simple installation.

via CocoaPods

Install CocoaPods if not already available:

	$ [sudo] gem install cocoapods
	$ pod setup
Change to the directory of your Xcode project, and Create and Edit your Podfile and add DCXMPP:

	$ cd /path/to/MyProject
	$ touch Podfile
	$ edit Podfile
	platform :ios, '5.0' 
	# Or platform :osx, '10.7'
	pod 'DCXMPP'

Install into your project:

	$ pod install
	
Open your project in Xcode from the .xcworkspace file (not the usual project file)

# License #

DCXMPP is license under the Apache License.

# Contact #

### Dalton Cherry ###
* https://github.com/daltoniam
* http://twitter.com/daltoniam
