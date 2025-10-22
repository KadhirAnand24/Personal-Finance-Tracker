<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%
    // Invalidate the current session
    if (session != null) {
        session.invalidate();
    }
    
    // Set success message in request scope to display on login page
    request.setAttribute("successMessage", "You have been logged out successfully.");
    
    // Redirect to login page
    response.sendRedirect("login.jsp?message=loggedOut");
    return;
%>