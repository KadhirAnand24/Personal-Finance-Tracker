<%@ page import="com.mongodb.*, com.mongodb.client.*, org.bson.*, java.util.*" %>
<%@ page import="static com.mongodb.client.model.Filters.*" %>
<%@ page import="org.bson.types.ObjectId" %> <!-- ADD THIS IMPORT -->
<%
    // MongoDB connection
    MongoClient mongoClient = null;
    MongoDatabase database = null;
    MongoCollection<Document> usersCollection = null;
    
    String successMsg = null;
    String errorMsg = null;
    
    try {
        Properties props = new Properties();
        props.load(getServletContext().getResourceAsStream("/WEB-INF/config.properties"));
        String connectionString = props.getProperty("mongodb.uri", "mongodb://localhost:27017/finance_tracker");
        
        mongoClient = MongoClients.create(connectionString);
        database = mongoClient.getDatabase("finance_tracker");
        usersCollection = database.getCollection("users");
        
    } catch (Exception e) {
        errorMsg = "Database connection failed: " + e.getMessage();
    }

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String username = request.getParameter("username");
        String password = request.getParameter("password");

        if (username != null && password != null) {
            if (mongoClient != null) {
                try {
                    // Check if username already exists
                    Document existingUser = usersCollection.find(eq("username", username)).first();
                    if (existingUser != null) {
                        errorMsg = "Username already exists!";
                    } else {
                        // Create new user
                        Document user = new Document()
                            .append("_id", new ObjectId())
                            .append("username", username)
                            .append("password", password)
                            .append("created_at", new java.util.Date())
                            .append("global_limit", 0.0);
                        
                        usersCollection.insertOne(user);
                        successMsg = "Registration successful! Please login.";
                    }
                } catch (Exception e) {
                    errorMsg = "Registration error: " + e.getMessage();
                }
            } else {
                errorMsg = "Database not available";
            }
        }
    }
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Register - Finance Tracker</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body {
            background: linear-gradient(135deg, #38bdf8, #0ea5e9);
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            font-family: 'Segoe UI', sans-serif;
        }
        .card {
            background: #fff;
            border-radius: 12px;
            padding: 30px;
            width: 100%;
            max-width: 380px;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);
            border: none;
        }
        .card h2 {
            text-align: center;
            margin-bottom: 20px;
            color: #0ea5e9;
        }
        .btn-primary {
            background: #38bdf8;
            border: none;
        }
        .btn-primary:hover {
            background: #0ea5e9;
        }
    </style>
</head>
<body>

<div class="card">
    <h2>Create Account</h2>

    <% if (errorMsg != null) { %>
        <div class="alert alert-danger"><%= errorMsg %></div>
    <% } %>
    <% if (successMsg != null) { %>
        <div class="alert alert-success"><%= successMsg %> <a href="login.jsp">Login here</a></div>
    <% } %>

    <form method="post">
        <div class="mb-3">
            <label class="form-label">Username</label>
            <input type="text" name="username" class="form-control" required>
        </div>
        <div class="mb-3">
            <label class="form-label">Password</label>
            <input type="password" name="password" class="form-control" required>
        </div>
        <button class="btn btn-primary w-100">Register</button>
        <p class="mt-3 text-center">Already have an account? <a href="login.jsp">Login</a></p>
    </form>
</div>

</body>
</html>
