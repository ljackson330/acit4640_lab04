To start, use the command ssh-keygen -t rsa -b 4096 -C "your_email@example_email.com" to generate a new key pair. 

open the cloud-config.yaml file which will hold our pulbic key as well as our packages.

Underneath the section labeled ssh-authorized-keys, add the contents of the public key. 

In a new block add a new section named "packages:", add 
-nginx
-nmap 
underneath these to install the required packages. 

In a new block underneath that one, create "runcmd:" with 
- systemctl enable nginx
- systemctl start nginx
