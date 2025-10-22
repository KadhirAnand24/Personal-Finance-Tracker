<%@ page import="java.sql.*" %>
<%
    Connection conn = (Connection) application.getAttribute("DBConnection");

    if (conn == null || conn.isClosed()) {
        try {
            // Load MySQL JDBC Driver
            Class.forName("com.mysql.cj.jdbc.Driver");

            // Create a connection
            conn = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/finance_tracker?useUnicode=true&characterEncoding=utf8&serverTimezone=UTC",
                "root",   // change to your DB username
                "root"    // change to your DB password
            );

            // Store connection object in application scope
            application.setAttribute("DBConnection", conn);
            out.println("<p style='color:green'>✅ DB Connected successfully!</p>");

        } catch (Exception e) {
            out.println("<p style='color:red'>❌ DB connection failed: " + e.getMessage() + "</p>");
            e.printStackTrace();
        }
    }
%>
