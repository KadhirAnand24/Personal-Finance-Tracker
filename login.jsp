<%@ page import="com.mongodb.*, com.mongodb.client.*, org.bson.*, java.util.*" %>
<%@ page import="static com.mongodb.client.model.Filters.*" %>
<%@ page import="org.bson.types.ObjectId" %>
<%
    // MongoDB connection
    MongoClient mongoClient = null;
    MongoDatabase database = null;
    MongoCollection<Document> usersCollection = null;
    
    // Initialize errorMsg outside try-catch block
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

    String username = request.getParameter("username");
    String password = request.getParameter("password");

    if (username != null && password != null && mongoClient != null) {
        try {
            Document user = usersCollection.find(and(eq("username", username), eq("password", password))).first();
            if (user != null) {
                session.setAttribute("userId", user.getObjectId("_id").toString());
                session.setAttribute("username", username);
                response.sendRedirect("tracker.jsp");
                return;
            } else {
                errorMsg = "Invalid username or password";
            }
        } catch (Exception e) {
            errorMsg = "Login error: " + e.getMessage();
        }
    } else if (username != null && password != null) {
        errorMsg = "Database not available";
    }
%>

<!DOCTYPE html>
<html>
<head>
    <title>Login - Finance Tracker</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
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
        .login-container {
            background: #fff;
            border-radius: 12px;
            padding: 30px;
            width: 100%;
            max-width: 380px;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);
        }
        .login-container h2 {
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
        .error-text {
            color: red;
            text-align: center;
            margin-bottom: 10px;
        }
    </style>
</head>
<body>

<div class="login-container">
    <h2>Finance Tracker</h2>

    <% if (errorMsg != null) { %>
        <div class="alert alert-danger"><%= errorMsg %></div>
    <% } %>

    <form method="post" action="login.jsp">
        <div class="mb-3">
            <label class="form-label">Username</label>
            <input type="text" name="username" class="form-control" required placeholder="Enter username">
        </div>
        <div class="mb-3">
            <label class="form-label">Password</label>
            <input type="password" name="password" class="form-control" required placeholder="Enter password">
        </div>
        <div class="d-grid">
            <button type="submit" class="btn btn-primary">Login</button>
        </div>
        <p class="mt-3 text-center">Don't have an account? <a href="register.jsp">Register</a></p>
    </form>
</div>

</body>
</html>
