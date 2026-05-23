sudo yum install httpd -y 
# or use 'apt-get install apache2' for Debian/Ubuntu systems

sudo systemctl start httpd
sudo systemctl enable --now httpd

sudo systemctl status httpd

echo "<html><body><h1>Hello World Public</h1></body></html>" | sudo tee /var/www/html/index.html
