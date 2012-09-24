GIS
======================

Gitorious Ubuntu 12.04 Server Post-install Script
Thanks to Lucas Jenß ( for initial instructions @ http://coding-journal.com/author/x3ro/)

Authors:
Ezra Bowden - V1 - http://blog.kyodium.net
	- Initial Script
	- Working with 11.04

Nathan Hold - V2 - https://github.com/nhold/
	- Code cleanup
 	- Working with 12.04

Starts with a base 12.04 server installation, no packages/groups added during OS installation.
It's best to install the server, then ssh in and run the script because there's a couple of steps
that'll be much easier if you can copy/paste.

Running this script as root (sudo sh <scriptname>) against a base 12.04 server install should
have you up and running without any additional fiddling around. Let me know if you see a better way
to do this, or find any glaring errors.