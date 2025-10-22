FROM tomcat:9-jdk17-openjdk

# Copy your WAR file to Tomcat
COPY ./myapp.war /usr/local/tomcat/webapps/ROOT.war

# Expose port
EXPOSE 8080

# Start Tomcat
CMD ["catalina.sh", "run"]
