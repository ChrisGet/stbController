### Instructions for setting up your new STB Controller ###

############## STEP 1:
- Go to the scripts directory and run "perl initialSetup.pl" as root. This will set up file permissions as well as other things for the controller

- Upgrading to version 2.1 - Within the scripts directory, run the convertSTBDB.pl script. This will convert the old STB database file to the new JSON format.

- Upgrading to version 2.3 - Within the scripts directory, run "perl initialSetup.pl" as root or sudo. This will setup the new features needed for RedRatHub and IR functionality.

############## STEP 2:
- Below is a list of perl modules that the controller requires. These can be installed using CPAN.
	(To install CPAN in Debian, run "apt-get install libcpan-meta-perl").
	Packages to install:-
	- IO::Socket::INET
	- CGI
	- LWP::UserAgent
	- HTTP::Request
	- Tie::File::AsHash
	- Schedule::Cron
	- Time::HiRes
	- FindBin
	- JSON
	- Proc::ProcessTable
	- Digest::MD5
	- Net::Telnet

- Handy cpan command for installing these modules (While in the cpan shell)
install IO::Socket::INET CGI LWP::UserAgent HTTP::Request Tie::File::AsHash Schedule::Cron Time::HiRes FindBin JSON Proc::ProcessTable Digest::MD5 Net::Telnet

- Install the package libusb-1.0-0-dev via your package manager.

############## STEP 3:
- Set up the web server:-
- Here is an example of the settings that need to be configured in the Apache config file for your web page:

#####
<VirtualHost *:80> 
     ServerAdmin webmaster@example.net
     ServerName example.net
     ServerAlias www.example.net
     DocumentRoot /srv/www/example.net/public_html/
     ErrorLog /srv/www/example.net/logs/error.log 
     CustomLog /srv/www/example.net/logs/access.log combined
     Options ExecCGI Indexes FollowSymLinks
     AddHandler cgi-script .pl .cgi
</VirtualHost>
#####

- The "Options" and "AddHandler" parts are key to enabling all functionality for the stbController. Everything else will be according to your personal setup

- Once you have Apache setup and your website configured, you will need to go to the root directory for the web page
(where you defined "DocumentRoot" for your web page) and create some directories and symbolic links.

	*** In the web page root directory

	- Create a directory called "cgi-bin". In this directory you now need to create a symbolic link called "scripts"
	  which links to the "stbController/scripts/" directory.
	- Create a symbolic link called "web" which links to the "stbController/web" directory.
	- Create a symbolic link called "exports" which links to the "stbController/files/exports" directory.
	- Create a symbolic link called "index.html" which links to the "stbController/web/index.html" file.
	- NOTE: File and folder permissions may have to be tweaked according to your Apache setup. Keep an eye on the error log file for your web page to see where these need to be changed if needed.

- Once the directories and symbolic links are created you should be good to go. Navigate to your web page to view the stbController
