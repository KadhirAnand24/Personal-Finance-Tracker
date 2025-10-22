<%@ page import="java.util.*, java.text.*, com.mongodb.*, com.mongodb.client.*, org.bson.*, com.mongodb.client.model.*" %>
<%@ page import="static com.mongodb.client.model.Filters.*" %>
<%@ page import="static com.mongodb.client.model.Updates.*" %>
<%@ page import="static com.mongodb.client.model.Aggregates.*" %>
<%@ page import="static com.mongodb.client.model.Accumulators.*" %>
<%@ page import="static com.mongodb.client.model.Sorts.*" %>
<%@ page import="java.io.*" %>
<%@ page import="org.bson.types.ObjectId" %>
<%@ page import="org.bson.conversions.Bson" %>
<%!
    // Safe number parsing method
    private double parseSafeDouble(String value) throws NumberFormatException {
        if (value == null || value.trim().isEmpty()) {
            throw new NumberFormatException("Empty input");
        }
        String cleanValue = value.trim().replaceAll("\\s+", "");
        if (!cleanValue.matches("^\\d+(\\.\\d{1,2})?$")) {
            throw new NumberFormatException("Invalid number format");
        }
        double result = Double.parseDouble(cleanValue);
        if (result < 0 || result > 10000000) {
            throw new NumberFormatException("Amount out of range");
        }
        return result;
    }

    private boolean isValidString(String input) {
        return input != null && !input.trim().isEmpty() && input.length() <= 255;
    }

    private boolean isValidCategoryName(String name) {
        return name != null && name.trim().length() >= 2 && 
               name.trim().length() <= 50 && 
               name.matches("^[a-zA-Z0-9\\s\\-&]+$");
    }
    
    private String escapeHtml(String input) {
        if (input == null) return "";
        return input.replace("&", "&amp;")
                   .replace("<", "&lt;")
                   .replace(">", "&gt;")
                   .replace("\"", "&quot;")
                   .replace("'", "&#39;");
    }
    
    // MongoDB ObjectId validation
    private boolean isValidObjectId(String id) {
        return id != null && id.matches("^[0-9a-fA-F]{24}$");
    }
%>
<%
    // Check if user is logged in (MongoDB session)
    String loggedInUserId = (String) session.getAttribute("userId");
    if (loggedInUserId == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    // Initialize variables
    double totalIncome = 0;
    double totalExpense = 0;
    double balance = 0;
    double globalLimit = 0;
    List<Document> categories = new ArrayList<>();
    Map<String, List<Document>> expensesByCategory = new HashMap<>();
    String errorMessage = null;
    String userId = loggedInUserId;

    // MongoDB connection
    MongoClient mongoClient = null;
    MongoDatabase database = null;
    MongoCollection<Document> usersCollection = null;
    MongoCollection<Document> categoriesCollection = null;
    MongoCollection<Document> expensesCollection = null;
    MongoCollection<Document> incomesCollection = null;
    
    Properties props = new Properties();
    String connectionString = "mongodb://localhost:27017/finance_tracker";
    boolean dbConnected = false;
    
    // First, try environment variable (for Render)
    String envMongoUri = System.getenv("MONGODB_URI");
    if (envMongoUri != null && !envMongoUri.trim().isEmpty()) {
        connectionString = envMongoUri;
        out.println("<!-- Using MONGODB_URI from environment -->");
    } else {
    // Fallback to config.properties (for local development)
        try {
            Properties props = new Properties();
            props.load(getServletContext().getResourceAsStream("/WEB-INF/config.properties"));
            connectionString = props.getProperty("mongodb.uri", connectionString);
            out.println("<!-- Using config.properties -->");
        } catch (Exception e) {
            out.println("<!-- Config load error: " + e.getMessage() + " -->");
            errorMessage = "Configuration error: " + e.getMessage();
        }
    }

    try {
        MongoClientSettings settings = MongoClientSettings.builder()
            .applyConnectionString(new ConnectionString(connectionString))
            .applyToSslSettings(builder -> {
                builder.enabled(true);
                builder.invalidHostNameAllowed(true);
            })
            .applyToSocketSettings(builder -> 
                builder.connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            )
            .build();
            
        mongoClient = MongoClients.create(settings);
        mongoClient.listDatabaseNames().first();
        database = mongoClient.getDatabase("finance_tracker");
        
        usersCollection = database.getCollection("users");
        categoriesCollection = database.getCollection("categories");
        expensesCollection = database.getCollection("expenses");
        incomesCollection = database.getCollection("incomes");
        
        dbConnected = true;
        out.println("<!-- MongoDB Connected Successfully -->");
        
    } catch (Exception e) {
        out.println("<!-- MongoDB Connection Failed: " + e.getMessage() + " -->");
        errorMessage = "Database connection failed. Running in demo mode.";
    }

    // AUTO-CREATE COLLECTIONS IF THEY DON'T EXIST
    if (dbConnected) {
        try {
            List<String> collectionNames = new ArrayList<>();
            for (String name : database.listCollectionNames()) {
                collectionNames.add(name);
            }
            
            if (!collectionNames.contains("users")) {
                database.createCollection("users");
                out.println("<!-- Created users collection -->");
            }
            if (!collectionNames.contains("categories")) {
                database.createCollection("categories");
                out.println("<!-- Created categories collection -->");
            }
            if (!collectionNames.contains("expenses")) {
                database.createCollection("expenses");
                out.println("<!-- Created expenses collection -->");
            }
            if (!collectionNames.contains("incomes")) {
                database.createCollection("incomes");
                out.println("<!-- Created incomes collection -->");
            }
        } catch (Exception e) {
            out.println("<!-- Collection creation error: " + e.getMessage() + " -->");
        }
    }

    // Demo data for when connection fails
    if (!dbConnected) {
        categories.add(new Document("_id", new ObjectId())
            .append("name", "Food & Dining")
            .append("color", "#60A5FA")
            .append("limit_amount", 500.0)
            .append("total", 325.50));
            
        categories.add(new Document("_id", new ObjectId())
            .append("name", "Transportation")
            .append("color", "#34D399")
            .append("limit_amount", 300.0)
            .append("total", 180.25));
            
        categories.add(new Document("_id", new ObjectId())
            .append("name", "Entertainment")
            .append("color", "#FBBF24")
            .append("limit_amount", 200.0)
            .append("total", 75.80));
            
        totalIncome = 2500.00;
        totalExpense = 581.55;
        balance = totalIncome - totalExpense;
        globalLimit = 1500.00;
    }

    // Load data from MongoDB if connected
    if (dbConnected && mongoClient != null && userId != null) {
        try {
            ObjectId userObjectId = new ObjectId(userId);
            
            Document userDoc = usersCollection.find(eq("_id", userObjectId)).first();
            if (userDoc != null) {
                Double limit = userDoc.getDouble("global_limit");
                globalLimit = limit != null ? limit : 0.0;
            }

            // Get total income
            List<? extends Bson> incomePipeline = Arrays.asList(
                match(eq("user_id", userObjectId)),
                group(null, sum("total", "$amount"))
            );
            
            AggregateIterable<Document> incomeResult = incomesCollection.aggregate(incomePipeline);
            Document incomeDoc = incomeResult.first();
            if (incomeDoc != null) {
                Double income = incomeDoc.getDouble("total");
                totalIncome = income != null ? income : 0.0;
            }

            // Get categories for this user
            FindIterable<Document> categoriesCursor = categoriesCollection.find(eq("user_id", userObjectId));
            String[] defaultColors = {"#60A5FA", "#34D399", "#FBBF24", "#F87171", "#A78BFA", "#38BDF8", "#A3E635", "#FB923C"};
            int colorIndex = 0;
            
            for (Document category : categoriesCursor) {
                if (category.getString("color") == null) {
                    category.put("color", defaultColors[colorIndex % defaultColors.length]);
                }
                if (category.getDouble("limit_amount") == null) {
                    category.put("limit_amount", 0.0);
                }
                categories.add(category);
                colorIndex++;
            }

            // Get expenses for all categories
            if (!categories.isEmpty()) {
                List<ObjectId> categoryIds = new ArrayList<>();
                for (Document category : categories) {
                    categoryIds.add(category.getObjectId("_id"));
                }
                
                // Calculate category totals
                for (Document category : categories) {
                    ObjectId catId = category.getObjectId("_id");
                    
                    List<? extends Bson> catExpensePipeline = Arrays.asList(
                        match(eq("category_id", catId)),
                        group(null, sum("total", "$amount"))
                    );
                    
                    AggregateIterable<Document> catExpenseResult = expensesCollection.aggregate(catExpensePipeline);
                    Document catTotalDoc = catExpenseResult.first();
                    double catTotal = 0.0;
                    if (catTotalDoc != null) {
                        Double total = catTotalDoc.getDouble("total");
                        catTotal = total != null ? total : 0.0;
                    }
                    
                    category.put("total", catTotal);
                    totalExpense += catTotal;
                }
                
                // Get individual expenses
                FindIterable<Document> expensesCursor = expensesCollection.find(in("category_id", categoryIds))
                    .sort(descending("spent_at"));
                
                for (Document expense : expensesCursor) {
                    ObjectId catId = expense.getObjectId("category_id");
                    String catIdStr = catId.toString();
                    
                    if (!expensesByCategory.containsKey(catIdStr)) {
                        expensesByCategory.put(catIdStr, new ArrayList<>());
                    }
                    expensesByCategory.get(catIdStr).add(expense);
                }
            }

            balance = totalIncome - totalExpense;

        } catch (Exception e) {
            errorMessage = "Database error: " + e.getMessage();
            out.println("<!-- MongoDB error: " + e.getMessage() + " -->");
        }
    }

    // Handle form actions - NO REDIRECTS, NO SUCCESS MESSAGES
    // Handle form actions - WITH REDIRECTS to prevent duplicate submissions
String action = request.getParameter("action");
if (action != null) {
    if (dbConnected && mongoClient != null && userId != null) {
        try {
            ObjectId userObjectId = new ObjectId(userId);
            
            // CSRF token validation
            String sessionToken = (String) session.getAttribute("csrfToken");
            String requestToken = request.getParameter("csrfToken");
            
            if (sessionToken == null) {
                sessionToken = java.util.UUID.randomUUID().toString();
                session.setAttribute("csrfToken", sessionToken);
            }
            
            if (requestToken == null || !sessionToken.equals(requestToken)) {
                errorMessage = "Security validation failed. Please try again.";
            } else if ("addIncome".equals(action)) {
                String amountStr = request.getParameter("incomeAmount");
                if (isValidString(amountStr)) {
                    try {
                        double amount = parseSafeDouble(amountStr);
                        Document income = new Document()
                            .append("user_id", userObjectId)
                            .append("amount", amount)
                            .append("income_date", new java.util.Date())
                            .append("created_at", new java.util.Date());
                        incomesCollection.insertOne(income);
                        // REDIRECT to prevent duplicate submissions
                        response.sendRedirect("tracker.jsp");
                        return;
                    } catch (NumberFormatException e) {
                        errorMessage = "Invalid amount format. Please enter a valid number.";
                    }
                } else {
                    errorMessage = "Please enter an income amount.";
                }
            }
            else if ("setGlobalLimit".equals(action)) {
                String limitStr = request.getParameter("globalLimit");
                if (isValidString(limitStr)) {
                    try {
                        double newLimit = parseSafeDouble(limitStr);
                        usersCollection.updateOne(
                            eq("_id", userObjectId),
                            set("global_limit", newLimit)
                        );
                        // REDIRECT to prevent duplicate submissions
                        response.sendRedirect("tracker.jsp");
                        return;
                    } catch (NumberFormatException e) {
                        errorMessage = "Invalid limit amount. Please enter a valid number.";
                    }
                } else {
                    errorMessage = "Please enter a global limit amount.";
                }
            }
            else if ("addCategory".equals(action)) {
                String catName = request.getParameter("newCategory");
                if (isValidCategoryName(catName)) {
                    // Check if category already exists for this user
                    Document existingCategory = categoriesCollection.find(
                        and(eq("user_id", userObjectId), eq("name", catName.trim()))
                    ).first();
                    
                    if (existingCategory != null) {
                        errorMessage = "Category '" + catName + "' already exists.";
                    } else {
                        String[] colors = {"#60A5FA", "#34D399", "#FBBF24", "#F87171", "#A78BFA", "#38BDF8", "#A3E635", "#FB923C"};
                        Document category = new Document()
                            .append("user_id", userObjectId)
                            .append("name", catName.trim())
                            .append("color", colors[categories.size() % colors.length])
                            .append("limit_amount", 0.0)
                            .append("created_at", new java.util.Date());
                        categoriesCollection.insertOne(category);
                        // REDIRECT to prevent duplicate submissions
                        response.sendRedirect("tracker.jsp");
                        return;
                    }
                } else {
                    errorMessage = "Category name must be 2-50 characters long and contain only letters, numbers, spaces, hyphens, and ampersands.";
                }
            }
            else if ("deleteCategory".equals(action)) {
                String catIdStr = request.getParameter("categoryId");
                if (isValidObjectId(catIdStr)) {
                    ObjectId catId = new ObjectId(catIdStr);
                    expensesCollection.deleteMany(eq("category_id", catId));
                    categoriesCollection.deleteOne(
                        and(eq("_id", catId), eq("user_id", userObjectId))
                    );
                    // REDIRECT to prevent duplicate submissions
                    response.sendRedirect("tracker.jsp");
                    return;
                } else {
                    errorMessage = "Invalid category ID.";
                }
            }
            else if ("setCatLimit".equals(action)) {
                String catIdStr = request.getParameter("categoryId");
                String limitStr = request.getParameter("limit");
                if (isValidObjectId(catIdStr) && isValidString(limitStr)) {
                    try {
                        ObjectId catId = new ObjectId(catIdStr);
                        double limit = parseSafeDouble(limitStr);
                        categoriesCollection.updateOne(
                            and(eq("_id", catId), eq("user_id", userObjectId)),
                            set("limit_amount", limit)
                        );
                        // REDIRECT to prevent duplicate submissions
                        response.sendRedirect("tracker.jsp");
                        return;
                    } catch (NumberFormatException e) {
                        errorMessage = "Invalid limit amount. Please enter a valid number.";
                    }
                } else {
                    errorMessage = "Please enter a valid category limit.";
                }
            }
            else if ("addExpense".equals(action)) {
                String catIdStr = request.getParameter("categoryId");
                String amountStr = request.getParameter("amount");
                String item = request.getParameter("item");
                if (isValidObjectId(catIdStr) && isValidString(amountStr) && isValidString(item)) {
                    try {
                        ObjectId catId = new ObjectId(catIdStr);
                        double amount = parseSafeDouble(amountStr);
                        Document expense = new Document()
                            .append("category_id", catId)
                            .append("amount", amount)
                            .append("item", item.trim())
                            .append("spent_at", new java.util.Date())
                            .append("created_at", new java.util.Date());
                        expensesCollection.insertOne(expense);
                        // REDIRECT to prevent duplicate submissions
                        response.sendRedirect("tracker.jsp");
                        return;
                    } catch (NumberFormatException e) {
                        errorMessage = "Invalid amount format. Please enter a valid number.";
                    }
                } else {
                    errorMessage = "Please fill in all expense fields.";
                }
            }
            else if ("deleteExpense".equals(action)) {
                String expIdStr = request.getParameter("expenseId");
                if (isValidObjectId(expIdStr)) {
                    ObjectId expId = new ObjectId(expIdStr);
                    expensesCollection.deleteOne(eq("_id", expId));
                    // REDIRECT to prevent duplicate submissions
                    response.sendRedirect("tracker.jsp");
                    return;
                } else {
                    errorMessage = "Invalid expense ID.";
                }
            }
            else if ("updateCategoryColor".equals(action)) {
                String catIdStr = request.getParameter("categoryId");
                String newColor = request.getParameter("color");
                if (isValidObjectId(catIdStr) && newColor != null && newColor.matches("^#[0-9A-Fa-f]{6}$")) {
                    ObjectId catId = new ObjectId(catIdStr);
                    categoriesCollection.updateOne(
                        and(eq("_id", catId), eq("user_id", userObjectId)),
                        set("color", newColor)
                    );
                    // REDIRECT to prevent duplicate submissions
                    response.sendRedirect("tracker.jsp");
                    return;
                } else {
                    errorMessage = "Please select a valid color.";
                }
            }
        } catch (Exception e) {
            errorMessage = "Database error: " + e.getMessage();
            out.println("<!-- Form action error: " + e.getMessage() + " -->");
        }
    } else {
        errorMessage = "Database not available. Please try again later.";
    }
}
    DecimalFormat df = new DecimalFormat("#,##0.00");
    double globalPct = globalLimit > 0 ? (totalExpense / globalLimit) * 100.0 : 0.0;
    SimpleDateFormat dateFormat = new SimpleDateFormat("dd MMM yyyy");
    
    // Generate new CSRF token if not exists
    String csrfToken = (String) session.getAttribute("csrfToken");
    if (csrfToken == null) {
        csrfToken = java.util.UUID.randomUUID().toString();
        session.setAttribute("csrfToken", csrfToken);
    }
%>

<!DOCTYPE html>
<html lang="en">
<head>

    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Personal Finance Tracker</title>
    
    <link rel="icon" type="image/png" href="icon.png">
    
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        
        :root {
            --primary-color: #38bdf8;
            --secondary-color: #0ea5e9;
            --accent-color: #7dd3fc;
            --success-color: #4facfe;
            --warning-color: #43e97b;
            --danger-color: #fa709a;
            --heading-gradient: linear-gradient(135deg, #38bdf8 0%, #0ea5e9 100%);
            --light-bg: #f8f9fa;
            --card-shadow: 0 8px 25px rgba(0,0,0,0.1);
            --hover-shadow: 0 12px 35px rgba(0,0,0,0.15);
        }
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            background: var(--light-bg);
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            color: #333;
            line-height: 1.6;
            padding-bottom: 2rem;
            min-height: 100vh;
        }
        
        /* Header Styles */
        .app-header {
            background: var(--heading-gradient);
            color: white;
            padding: 1.5rem 0;
            margin-bottom: 2rem;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            position: relative;
        }
        
        .app-title {
            font-weight: 800;
            text-align: center;
            margin: 0;
            font-size: 2.2rem;
            background: linear-gradient(45deg, #fff 0%, #f0f8ff 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            text-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        /* Hamburger Menu - FIXED POSITION */
        .hamburger-menu {
            position: fixed;
            top: 1rem;
            left: 1rem;
            z-index: 1000;
        }
        
        .hamburger-btn {
            background: rgba(255,255,255,0.2);
            border: 2px solid rgba(255,255,255,0.3);
            color: white;
            width: 40px;
            height: 42px;
            border-radius: 12px;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            cursor: pointer;
            transition: all 0.3s ease;
            backdrop-filter: blur(10px);
        }
        
        .hamburger-btn:hover {
            background: rgba(255,255,255,0.3);
            transform: scale(1.05);
        }
        
        .hamburger-icon {
            width: 20px;
            height: 18px;
            position: relative;
            transform: rotate(0deg);
            transition: .5s ease-in-out;
        }
        
        .hamburger-icon span {
            display: block;
            position: absolute;
            height: 3px;
            width: 100%;
            background: white;
            border-radius: 3px;
            opacity: 1;
            left: 0;
            transform: rotate(0deg);
            transition: .25s ease-in-out;
        }
        
        .hamburger-icon span:nth-child(1) { top: 0px; }
        .hamburger-icon span:nth-child(2) { top: 7px; }
        .hamburger-icon span:nth-child(3) { top: 14px; }
        
        /* Hamburger Menu Open State */
        .hamburger-btn.active .hamburger-icon span:nth-child(1) {
            top: 7px;
            transform: rotate(135deg);
        }
        
        .hamburger-btn.active .hamburger-icon span:nth-child(2) {
            opacity: 0;
            left: -60px;
        }
        
        .hamburger-btn.active .hamburger-icon span:nth-child(3) {
            top: 7px;
            transform: rotate(-135deg);
        }
        
        /* Sidebar Menu */
        .sidebar-menu {
            position: fixed;
            top: 0;
            left: -300px;
            width: 280px;
            height: 100vh;
            background: white;
            box-shadow: 5px 0 25px rgba(0,0,0,0.1);
            transition: all 0.3s ease;
            z-index: 999;
            padding: 80px 1rem 2rem;
            overflow-y: auto;
        }
        
        .sidebar-menu.open {
            left: 0;
        }
        
        .sidebar-menu .menu-item {
            display: flex;
            align-items: center;
            padding: 1rem;
            margin-bottom: 0.5rem;
            border-radius: 10px;
            color: #333;
            text-decoration: none;
            transition: all 0.3s ease;
            border: none;
            background: none;
            width: 100%;
            text-align: left;
            font-size: 1rem;
            cursor: pointer;
        }
        
        .sidebar-menu .menu-item:hover {
            background: rgba(0, 0, 0, 0.05);
            color: #333;
            transform: translateX(5px);
        }
        
        .sidebar-menu .menu-item i {
            width: 20px;
            margin-right: 1rem;
            font-size: 1.1rem;
        }
        
        .menu-overlay {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.5);
            z-index: 998;
            opacity: 0;
            visibility: hidden;
            transition: all 0.3s ease;
        }
        
        .menu-overlay.active {
            opacity: 1;
            visibility: visible;
        }
        
        /* Metrics Grid */
        .metrics-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            grid-template-rows: auto auto;
            gap: 1rem;
            margin-bottom: 3rem;
            padding: 0 1rem;
        }
        
        @media (min-width: 768px) {
            .metrics-grid {
                grid-template-columns: repeat(4, 1fr);
                grid-template-rows: auto;
                gap: 1.5rem;
                padding: 0;
            }
        }
        
        .metric-card {
            background: white;
            padding: 1.5rem;
            border-radius: 16px;
            box-shadow: var(--card-shadow);
            border: 1px solid #000;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
            display: flex;
            flex-direction: column;
            align-items: center;
            text-align: center;
        }
        
        .metric-card:hover {
            transform: translateY(-5px);
            box-shadow: var(--hover-shadow);
            border-color: var(--primary-color);
        }
        
        .metric-icon {
            font-size: 2rem;
            color: var(--primary-color);
            margin-bottom: 1rem;
        }
        
        .metric-label {
            font-size: 0.8rem;
            font-weight: 600;
            color: #6c757d;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 0.5rem;
        }
        
        .metric-value {
            font-size: 1.75rem;
            font-weight: 700;
            color: var(--primary-color);
            margin-bottom: 0.5rem;
        }
        
        .metric-extra {
            font-size: 0.8rem;
            color: #6c757d;
            margin-bottom: 1rem;
        }
        
        /* Categories Section */
        .categories-section {
            margin-bottom: 3rem;
            padding: 0 1rem;
        }
        
        @media (min-width: 768px) {
            .categories-section {
                padding: 0;
            }
        }
        
        .section-title {
            font-weight: 700;
            color: var(--primary-color);
            margin-bottom: 1.5rem;
            font-size: 1.5rem;
            text-align: center;
        }
        
        .categories-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 1rem;
        }
        
        /* UPDATED: Full color category tiles */
        .category-tile {
            background: white;
            padding: 1.5rem;
            border-radius: 12px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.07);
            background: linear-gradient(135deg, var(--color) 0%, var(--color) 100%);
            color: white;
            cursor: pointer;
            transition: all 0.2s;
            position: relative;
            font-weight: 600;
            display: flex;
            align-items: center;
            justify-content: center;
            text-align: center;
            min-height: 100px;
            border: none;
        }
        
        .category-tile:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 12px rgba(0,0,0,0.1);
            filter: brightness(1.1);
        }
        
        .delete-category {
            position: absolute;
            top: 0.5rem;
            right: 0.5rem;
            background: rgba(255,255,255,0.9);
            border: none;
            color: #dc3545;
            opacity: 0;
            transition: opacity 0.2s;
            cursor: pointer;
            padding: 0.25rem;
            border-radius: 4px;
            width: 25px;
            height: 25px;
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 10;
        }
        
        .category-tile:hover .delete-category {
            opacity: 1;
        }
        
        .delete-category:hover {
            background: #dc3545;
            color: white;
        }
        
        .add-category-btn {
            background: #f8f9fa;
            border: 2px dashed #dee2e6;
            padding: 1.5rem;
            border-radius: 12px;
            cursor: pointer;
            transition: all 0.2s;
            color: #6c757d;
            font-weight: 600;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100px;
        }
        
        .add-category-btn:hover {
            background: #e9ecef;
            border-color: var(--accent-color);
            color: var(--accent-color);
            transform: translateY(-2px);
        }
        
        .progress {
            height: 8px;
            border-radius: 4px;
            margin: 0.5rem 0;
            width: 100%;
        }
        
        .btn {
            border-radius: 8px;
            font-weight: 600;
            transition: all 0.3s ease;
        }
        
        .btn-primary {
            background: var(--primary-color);
            border-color: var(--primary-color);
        }
        
        .btn-primary:hover {
            background: var(--secondary-color);
            border-color: var(--secondary-color);
            transform: translateY(-1px);
        }
        
        .alert {
            border-radius: 12px;
            border: none;
            margin-bottom: 1rem;
        }
        
        /* Color Picker Styles */
        .color-picker-dropdown {
            position: relative;
            margin-bottom: 1.5rem;
        }
        
        .color-dropdown-btn {
            width: 100%;
            padding: 0.75rem;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            background: white;
            display: flex;
            justify-content: space-between;
            align-items: center;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .color-dropdown-btn:hover {
            border-color: var(--primary-color);
        }
        
        .color-dropdown-content {
            display: none;
            position: absolute;
            background: white;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            padding: 1rem;
            width: 100%;
            z-index: 1000;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
        }
        
        .color-dropdown-content.show {
            display: block;
        }
        
        .color-options-grid {
            display: grid;
            grid-template-columns: repeat(6, 1fr);
            gap: 0.5rem;
            margin-bottom: 1rem;
        }
        
        .color-option {
            width: 30px;
            height: 30px;
            border-radius: 6px;
            cursor: pointer;
            border: 2px solid transparent;
            transition: all 0.2s;
        }
        
        .color-option:hover {
            transform: scale(1.1);
        }
        
        .color-option.selected {
            border-color: #333;
            transform: scale(1.1);
        }
        
        .color-preview {
            display: inline-block;
            width: 20px;
            height: 20px;
            border-radius: 4px;
            margin: 0 0.5rem;
            border: 1px solid #dee2e6;
        }
        
        @media (max-width: 576px) {
            .app-title {
                font-size: 1.8rem;
            }
            
            .metrics-grid {
                gap: 0.75rem;
                padding: 0 0.5rem;
            }
            
            .metric-card {
                padding: 1rem;
            }
            
            .metric-value {
                font-size: 1.5rem;
            }
            
            .categories-grid {
                grid-template-columns: 1fr 1fr;
            }
        }
    </style>
</head>
<body>
    <!-- Header -->
    <div class="app-header">
        <div class="container">
            <h1 class="app-title">Personal Finance Tracker</h1>
        </div>
    </div>

    <!-- Hamburger Menu - FIXED POSITION -->
    <div class="hamburger-menu">
        <button class="hamburger-btn" id="hamburgerBtn" aria-label="Main menu">
            <div class="hamburger-icon">
                <span></span>
                <span></span>
                <span></span>
            </div>
        </button>
    </div>

    <!-- Sidebar Menu -->
    <div class="sidebar-menu" id="sidebarMenu">
        <button class="menu-item" onclick="showColorGuide()">
            <i class="fas fa-palette"></i>
            <span>Color Guide</span>
        </button>
        <button class="menu-item" onclick="resetData()">
            <i class="fas fa-redo"></i>
            <span>Reset Data</span>
        </button>
        <button class="menu-item" onclick="exportData()">
            <i class="fas fa-download"></i>
            <span>Export Data</span>
        </button>
        <button class="menu-item" onclick="printReport()">
            <i class="fas fa-print"></i>
            <span>Print Report</span>
        </button>
        <button class="menu-item" onclick="showQuickStats()">
            <i class="fas fa-chart-bar"></i>
            <span>Quick Stats</span>
        </button>
        <div style="margin-top: 2rem; padding-top: 1rem; border-top: 1px solid #dee2e6;">
            <button class="menu-item text-danger" onclick="logout()">
                <i class="fas fa-sign-out-alt"></i>
                <span>Log Out</span>
            </button>
        </div>
    </div>

    <!-- Menu Overlay -->
    <div class="menu-overlay" id="menuOverlay"></div>

    <!-- Alert Messages - ONLY ERRORS -->
    <% if (errorMessage != null) { %>
    <div class="alert alert-danger alert-dismissible fade show mx-3" role="alert">
        <i class="fas fa-exclamation-triangle me-2"></i><%= errorMessage %>
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
    <% } %>

    <div class="container mt-4">
        <!-- Metrics Grid -->
        <div class="metrics-grid">
            <!-- Total Income -->
            <div class="metric-card">
                <div class="metric-icon"><i class="fas fa-money-bill-wave"></i></div>
                <div class="metric-label">TOTAL INCOME</div>
                <div class="metric-value">&#8377;<%= df.format(totalIncome) %></div>
                <form method="post" class="mt-3 w-100">
                    <input type="hidden" name="action" value="addIncome"/>
                    <input type="hidden" name="csrfToken" value="<%= csrfToken %>"/>
                    <div class="input-group input-group-sm">
                        <input type="number" step="0.01" min="0" max="1000000" name="incomeAmount" 
                               class="form-control" placeholder="Amount" required>
                        <button class="btn btn-primary btn-sm">
                            <i class="fas fa-plus me-1"></i>Add
                        </button>
                    </div>
                </form>
            </div>

            <!-- Spending -->
            <div class="metric-card">
                <div class="metric-icon"><i class="fas fa-shopping-cart"></i></div>
                <div class="metric-label">SPENDING</div>
                <div class="metric-value">&#8377;<%= df.format(totalExpense) %></div>
                <div class="metric-extra">Across all categories</div>
            </div>

            <!-- Balance -->
            <div class="metric-card">
                <div class="metric-icon"><i class="fas fa-balance-scale"></i></div>
                <div class="metric-label">BALANCE</div>
                <div class="metric-value <%= balance >= 0 ? "text-success" : "text-danger" %>">
                    &#8377;<%= df.format(balance) %>
                </div>
                <div class="metric-extra"><%= balance >= 0 ? "Under budget" : "Over budget" %></div>
            </div>

            <!-- Global Limit -->
            <div class="metric-card">
                <div class="metric-icon"><i class="fas fa-bullseye"></i></div>
                <div class="metric-label">GLOBAL LIMIT</div>
                <div class="metric-value">&#8377;<%= df.format(globalLimit) %></div>
                <form method="post" class="mt-3 w-100">
                    <input type="hidden" name="action" value="setGlobalLimit"/>
                    <input type="hidden" name="csrfToken" value="<%= csrfToken %>"/>
                    <div class="input-group input-group-sm">
                        <input type="number" step="0.01" min="0" max="10000000" name="globalLimit" 
                               class="form-control" placeholder="Set limit" value="<%= globalLimit %>" required>
                        <button class="btn btn-outline-primary btn-sm">
                            <i class="fas fa-save me-1"></i>Save
                        </button>
                    </div>
                </form>
                <div class="progress">
                    <div class="progress-bar <%= globalPct >= 100 ? "bg-danger" : (globalPct >= 80 ? "bg-warning" : "bg-success") %>" 
                         style="width: <%= Math.min(globalPct, 100) %>%"
                         role="progressbar" 
                         aria-valuenow="<%= Math.min(globalPct, 100) %>" 
                         aria-valuemin="0" 
                         aria-valuemax="100">
                    </div>
                </div>
                <div class="metric-extra"><%= String.format("%.1f", Math.min(globalPct, 100)) %>% of limit used</div>
            </div>
        </div>

        <!-- Categories Section -->
        <div class="categories-section">
            <h2 class="section-title">CATEGORIES</h2>
            
            <div class="categories-grid">
                <% for (Document category : categories) { 
                    String catId = category.getObjectId("_id").toString();
                    String catName = escapeHtml(category.getString("name"));
                    String catColor = category.getString("color");
                    double catLimit = category.getDouble("limit_amount") != null ? category.getDouble("limit_amount") : 0.0;
                    double catTotal = category.getDouble("total") != null ? category.getDouble("total") : 0.0;
                    double catPct = catLimit > 0 ? (catTotal / catLimit) * 100.0 : 0.0;
                %>
                <div class="category-tile" style="--color: <%= catColor %>;"
                     data-bs-toggle="modal" data-bs-target="#modal_<%= catId %>"
                     aria-label="View <%= catName %> expenses">
                    <%= catName %>
                    <button class="delete-category" 
                            onclick="event.stopPropagation(); showDeleteModal('<%= catId %>', '<%= catName %>')"
                            aria-label="Delete <%= catName %> category">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <% } %>

                <button class="add-category-btn" data-bs-toggle="modal" data-bs-target="#addCategoryModal"
                        aria-label="Add new category">
                    <i class="fas fa-plus me-2"></i>ADD CATEGORY
                </button>
            </div>
        </div>
    </div>

    <!-- Category Detail Modals -->
    <% for (Document category : categories) { 
        String catId = category.getObjectId("_id").toString();
        String catName = escapeHtml(category.getString("name"));
        String catColor = category.getString("color");
        double catLimit = category.getDouble("limit_amount") != null ? category.getDouble("limit_amount") : 0.0;
        double catTotal = category.getDouble("total") != null ? category.getDouble("total") : 0.0;
        double catPct = catLimit > 0 ? (catTotal / catLimit) * 100.0 : 0.0;
        
        List<Document> categoryExpenses = expensesByCategory.get(catId);
    %>
    <div class="modal fade" id="modal_<%= catId %>" tabindex="-1" aria-labelledby="modalLabel_<%= catId %>" aria-hidden="true">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header" style="background: <%= catColor %>; color: white;">
                    <h5 class="modal-title" id="modalLabel_<%= catId %>">
                        <i class="fas fa-folder me-2"></i>
                        <%= catName %>
                    </h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <!-- Category Stats -->
                    <div class="row mb-4">
                        <div class="col-md-6">
                            <div class="card">
                                <div class="card-body">
                                    <h6 class="card-title">Spent</h6>
                                    <h3 class="text-primary">&#8377;<%= df.format(catTotal) %></h3>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="card">
                                <div class="card-body">
                                    <h6 class="card-title">Limit</h6>
                                    <h3 class="text-info">&#8377;<%= df.format(catLimit) %></h3>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <!-- Progress Bar -->
                    <div class="mb-4">
                        <div class="d-flex justify-content-between mb-2">
                            <span>Usage</span>
                            <span><%= String.format("%.1f", Math.min(catPct, 100)) %>%</span>
                        </div>
                        <div class="progress" style="height: 10px;">
                            <div class="progress-bar <%= catPct >= 100 ? "bg-danger" : (catPct >= 80 ? "bg-warning" : "bg-success") %>" 
                                 style="width: <%= Math.min(catPct, 100) %>%">
                            </div>
                        </div>
                    </div>
                    
                    <!-- Update Limit Form -->
                    <form method="post" class="mb-4">
                        <input type="hidden" name="action" value="setCatLimit"/>
                        <input type="hidden" name="categoryId" value="<%= catId %>"/>
                        <input type="hidden" name="csrfToken" value="<%= csrfToken %>"/>
                        <div class="input-group">
                            <input type="number" step="0.01" min="0" max="1000000" name="limit" 
                                   class="form-control" placeholder="Set category limit" value="<%= catLimit %>" required>
                            <button class="btn btn-primary">
                                <i class="fas fa-save me-1"></i>Update Limit
                            </button>
                        </div>
                    </form>
                    
                    <!-- Color Picker -->
                    <div class="color-picker-dropdown mb-4">
                        <div class="color-dropdown-btn" onclick="toggleColorDropdown('<%= catId %>')">
                            <span>Category Color</span>
                            <div class="color-preview" style="background-color: <%= catColor %>"></div>
                            <i class="fas fa-chevron-down"></i>
                        </div>
                        <div class="color-dropdown-content" id="colorDropdown_<%= catId %>">
                            <div class="color-options-grid">
                                <div class="color-option <%= "#60A5FA".equals(catColor) ? "selected" : "" %>" 
                                     style="background-color: #60A5FA" 
                                     onclick="selectColor('<%= catId %>', '#60A5FA')"></div>
                                <div class="color-option <%= "#34D399".equals(catColor) ? "selected" : "" %>" 
                                     style="background-color: #34D399" 
                                     onclick="selectColor('<%= catId %>', '#34D399')"></div>
                                <div class="color-option <%= "#FBBF24".equals(catColor) ? "selected" : "" %>" 
                                     style="background-color: #FBBF24" 
                                     onclick="selectColor('<%= catId %>', '#FBBF24')"></div>
                                <div class="color-option <%= "#F87171".equals(catColor) ? "selected" : "" %>" 
                                     style="background-color: #F87171" 
                                     onclick="selectColor('<%= catId %>', '#F87171')"></div>
                                <div class="color-option <%= "#A78BFA".equals(catColor) ? "selected" : "" %>" 
                                     style="background-color: #A78BFA" 
                                     onclick="selectColor('<%= catId %>', '#A78BFA')"></div>
                                <div class="color-option <%= "#38BDF8".equals(catColor) ? "selected" : "" %>" 
                                     style="background-color: #38BDF8" 
                                     onclick="selectColor('<%= catId %>', '#38BDF8')"></div>
                            </div>
                            <div class="color-options-grid">
                                <div class="color-option <%= "#A3E635".equals(catColor) ? "selected" : "" %>" 
                                     style="background-color: #A3E635" 
                                     onclick="selectColor('<%= catId %>', '#A3E635')"></div>
                                <div class="color-option <%= "#FB923C".equals(catColor) ? "selected" : "" %>" 
                                     style="background-color: #FB923C" 
                                     onclick="selectColor('<%= catId %>', '#FB923C')"></div>
                                <div class="color-option <%= "#C084FC".equals(catColor) ? "selected" : "" %>" 
                                     style="background-color: #C084FC" 
                                     onclick="selectColor('<%= catId %>', '#C084FC')"></div>
                                <div class="color-option <%= "#22D3EE".equals(catColor) ? "selected" : "" %>" 
                                     style="background-color: #22D3EE" 
                                     onclick="selectColor('<%= catId %>', '#22D3EE')"></div>
                                <div class="color-option <%= "#4ADE80".equals(catColor) ? "selected" : "" %>" 
                                     style="background-color: #4ADE80" 
                                     onclick="selectColor('<%= catId %>', '#4ADE80')"></div>
                                <div class="color-option <%= "#FACC15".equals(catColor) ? "selected" : "" %>" 
                                     style="background-color: #FACC15" 
                                     onclick="selectColor('<%= catId %>', '#FACC15')"></div>
                            </div>
                        </div>
                    </div>
                    
                    <!-- Add Expense Form -->
                    <form method="post" class="mb-4">
                        <input type="hidden" name="action" value="addExpense"/>
                        <input type="hidden" name="categoryId" value="<%= catId %>"/>
                        <input type="hidden" name="csrfToken" value="<%= csrfToken %>"/>
                        <div class="row">
                            <div class="col-md-6">
                                <input type="text" name="item" class="form-control mb-2" placeholder="Item name" required>
                            </div>
                            <div class="col-md-4">
                                <input type="number" step="0.01" min="0" max="100000" name="amount" 
                                       class="form-control mb-2" placeholder="Amount" required>
                            </div>
                            <div class="col-md-2">
                                <button class="btn btn-success w-100">
                                    <i class="fas fa-plus"></i>
                                </button>
                            </div>
                        </div>
                    </form>
                    
                    <!-- Expenses List -->
                    <h6 class="mb-3">Recent Expenses</h6>
                    <% if (categoryExpenses != null && !categoryExpenses.isEmpty()) { %>
                        <div class="list-group">
                            <% for (Document expense : categoryExpenses) { 
                                String item = escapeHtml(expense.getString("item"));
                                double amount = expense.getDouble("amount");
                                Date spentAt = expense.getDate("spent_at");
                            %>
                            <div class="list-group-item d-flex justify-content-between align-items-center">
                                <div>
                                    <h6 class="mb-1"><%= item %></h6>
                                    <small class="text-muted"><%= dateFormat.format(spentAt) %></small>
                                </div>
                                <div class="d-flex align-items-center">
                                    <span class="text-danger me-3">&#8377;<%= df.format(amount) %></span>
                                    <form method="post" class="d-inline">
                                        <input type="hidden" name="action" value="deleteExpense"/>
                                        <input type="hidden" name="expenseId" value="<%= expense.getObjectId("_id").toString() %>"/>
                                        <input type="hidden" name="csrfToken" value="<%= csrfToken %>"/>
                                        <button type="submit" class="btn btn-sm btn-outline-danger">
                                            <i class="fas fa-trash"></i>
                                        </button>
                                    </form>
                                </div>
                            </div>
                            <% } %>
                        </div>
                    <% } else { %>
                        <p class="text-muted text-center">No expenses yet.</p>
                    <% } %>
                </div>
            </div>
        </div>
    </div>
    <% } %>

    <!-- Add Category Modal -->
    <div class="modal fade" id="addCategoryModal" tabindex="-1" aria-labelledby="addCategoryModalLabel" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="addCategoryModalLabel">Add New Category</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <form method="post" id="addCategoryForm">
                        <input type="hidden" name="action" value="addCategory"/>
                        <input type="hidden" name="csrfToken" value="<%= csrfToken %>"/>
                        <div class="mb-3">
                            <label for="newCategory" class="form-label">Category Name</label>
                            <input type="text" class="form-control" id="newCategory" name="newCategory" 
                                   placeholder="Enter category name" required
                                   pattern="[a-zA-Z0-9\s\-&]{2,50}" 
                                   title="Category name must be 2-50 characters long and contain only letters, numbers, spaces, hyphens, and ampersands.">
                            <div class="form-text">
                                Category name must be 2-50 characters. Only letters, numbers, spaces, hyphens, and ampersands are allowed.
                            </div>
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" form="addCategoryForm" class="btn btn-primary">Add Category</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Delete Category Modal -->
    <div class="modal fade" id="deleteCategoryModal" tabindex="-1" aria-labelledby="deleteCategoryModalLabel" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="deleteCategoryModalLabel">Delete Category</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <p>Are you sure you want to delete the category "<span id="deleteCatName"></span>"?</p>
                    <p class="text-danger"><small>This will also delete all expenses in this category. This action cannot be undone.</small></p>
                    <form method="post" id="deleteCategoryForm">
                        <input type="hidden" name="action" value="deleteCategory"/>
                        <input type="hidden" name="categoryId" id="deleteCatId"/>
                        <input type="hidden" name="csrfToken" value="<%= csrfToken %>"/>
                    </form>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" form="deleteCategoryForm" class="btn btn-danger">Delete Category</button>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Hamburger Menu Functionality
        const hamburgerBtn = document.getElementById('hamburgerBtn');
        const sidebarMenu = document.getElementById('sidebarMenu');
        const menuOverlay = document.getElementById('menuOverlay');

        function toggleMenu() {
            hamburgerBtn.classList.toggle('active');
            sidebarMenu.classList.toggle('open');
            menuOverlay.classList.toggle('active');
            
            document.body.style.overflow = sidebarMenu.classList.contains('open') ? 'hidden' : '';
        }

        if (hamburgerBtn) hamburgerBtn.addEventListener('click', toggleMenu);
        if (menuOverlay) menuOverlay.addEventListener('click', toggleMenu);

        document.querySelectorAll('.sidebar-menu .menu-item').forEach(item => {
            item.addEventListener('click', toggleMenu);
        });

        // Category Color Functions
        function toggleColorDropdown(catId) {
            const dropdown = document.getElementById('colorDropdown_' + catId);
            if (dropdown) {
                dropdown.classList.toggle('show');
            }
        }

        function selectColor(catId, color) {
            const dropdown = document.getElementById('colorDropdown_' + catId);
            if (dropdown) {
                dropdown.classList.remove('show');
            }
            
            // Submit form immediately
            const form = document.createElement('form');
            form.method = 'POST';
            form.action = window.location.href;
            
            const actionInput = document.createElement('input');
            actionInput.type = 'hidden';
            actionInput.name = 'action';
            actionInput.value = 'updateCategoryColor';
            
            const catIdInput = document.createElement('input');
            catIdInput.type = 'hidden';
            catIdInput.name = 'categoryId';
            catIdInput.value = catId;
            
            const colorInput = document.createElement('input');
            colorInput.type = 'hidden';
            colorInput.name = 'color';
            colorInput.value = color;
            
            const csrfInput = document.createElement('input');
            csrfInput.type = 'hidden';
            csrfInput.name = 'csrfToken';
            csrfInput.value = '<%= csrfToken %>';
            
            form.appendChild(actionInput);
            form.appendChild(catIdInput);
            form.appendChild(colorInput);
            form.appendChild(csrfInput);
            document.body.appendChild(form);
            
            form.submit();
        }

        // Close color dropdown when clicking outside
        document.addEventListener('click', function(e) {
            if (!e.target.closest('.color-picker-dropdown')) {
                document.querySelectorAll('.color-dropdown-content').forEach(dropdown => {
                    dropdown.classList.remove('show');
                });
            }
        });

        // FIXED: Delete category function
        function showDeleteModal(catId, catName) {
            // Close any currently open category modal
            const openModals = document.querySelectorAll('.modal.show');
            openModals.forEach(modal => {
                if (modal.id !== 'deleteCategoryModal') {
                    const modalInstance = bootstrap.Modal.getInstance(modal);
                    if (modalInstance) {
                        modalInstance.hide();
                    }
                }
            });
            
            const deleteCatName = document.getElementById('deleteCatName');
            const deleteCatId = document.getElementById('deleteCatId');
            
            if (deleteCatName && deleteCatId) {
                deleteCatName.textContent = catName;
                deleteCatId.value = catId;
                
                const deleteModal = new bootstrap.Modal(document.getElementById('deleteCategoryModal'));
                deleteModal.show();
            }
        }

        // Menu Functions
        function showColorGuide() {
            alert('Color Guide:\n\n• Green: Good usage (under 80%)\n• Yellow: Warning (80-99%)\n• Red: Over limit (100%+)');
        }

        function resetData() {
            if (confirm('Are you sure you want to reset all data? This cannot be undone.')) {
                alert('Reset functionality would be implemented here.');
            }
        }

        function logout() {
            if (confirm('Are you sure you want to log out?')) {
                window.location.href = 'logout.jsp';
            }
        }

        function printReport() {
            window.print();
        }

        function exportData() {
            alert('Export functionality would be implemented here.');
        }

        function showQuickStats() {
            alert('Quick stats functionality would be implemented here.');
        }
    </script>

    <!-- Footer -->
    <footer class="mt-5 py-4 bg-light border-top">
        <div class="container">
            <div class="row">
                <div class="col-md-6">
                    <h6 class="fw-bold">Personal Finance Tracker</h6>
                    <p class="text-muted small">Track your expenses, manage budgets, and achieve your financial goals.</p>
                </div>
                <div class="col-md-6 text-md-end">
                    <p class="text-muted small mt-2">&copy; 2025 Finance Tracker. All rights reserved.</p>
                </div>
            </div>
        </div>
    </footer>
</body>
</html>
