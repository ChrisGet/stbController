### Instructions for setting up your new STB Controller ###

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

- The "Options" and "AddHandler" parts are key to enabling all functionality for the stbController.

- Once you have Apache setup and your website configured, you will need to go to the root directory for the web page
(where you defined "DocumentRoot" for your web page) and create some directories and symbolic links.

	*** In the web page root directory

	- Create a directory called "cgi-bin". In this directory you now need to create a symbolic link called "scripts"
	  which links to the "stbController/scripts/" directory.
	- Create a symbolic link called "web" which links to the "stbController/web" directory.
	- Create a symbolic link called "index.html" which links to the "stbController/web/index.html" file.

- Once the directorys and symbolic links are created you will be good to go. Navigate to your web page to view the stbController
