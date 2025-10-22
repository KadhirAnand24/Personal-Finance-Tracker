<%@ page import="com.mongodb.*, com.mongodb.client.*, java.util.*, java.io.*" %>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
    <title>Test MongoDB Connection</title>
    <style>
        body { font-family: Arial; padding: 2rem; }
        .success { color: green; font-weight: bold; }
        .error { color: red; font-weight: bold; }
    </style>
</head>
<body>
    <h1>🧪 MongoDB Atlas Connection Test</h1>
    
    <%
    MongoClient mongoClient = null;
    try {
        // Load configuration from WEB-INF/config.properties
        Properties props = new Properties();
        String connectionString = "";
        
        try {
            props.load(getServletContext().getResourceAsStream("/WEB-INF/config.properties"));
            connectionString = props.getProperty("mongodb.uri");
            out.println("<p><strong>✅ Config:</strong> Loaded successfully</p>");
            out.println("<p><strong>🔗 Using:</strong> MongoDB Atlas</p>");
        } catch (Exception e) {
            out.println("<p class='error'><strong>❌ Config Error:</strong> " + e.getMessage() + "</p>");
            return;
        }

        // Test Atlas connection
        out.println("<p><strong>🔄 Connecting to MongoDB Atlas...</strong></p>");
        
        mongoClient = MongoClients.create(connectionString);
        MongoDatabase database = mongoClient.getDatabase("finance_tracker");
        
        out.println("<p class='success'>✅ <strong>SUCCESS:</strong> Connected to MongoDB Atlas!</p>");
        out.println("<p><strong>🗄️ Database:</strong> " + database.getName() + "</p>");
        
        // List collections to verify access
        out.println("<p><strong>📊 Collections:</strong></p>");
        for (String name : database.listCollectionNames()) {
            out.println("<p>✅ " + name + "</p>");
        }
        
    } catch (Exception e) {
        out.println("<p class='error'>❌ <strong>FAILED:</strong> " + e.getMessage() + "</p>");
    } finally {
        if (mongoClient != null) {
            mongoClient.close();
        }
    }
    %>
</body>
</html>