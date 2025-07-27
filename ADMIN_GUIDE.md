# Admin User Management System Guide

## Overview

The Marketer Gen platform includes a comprehensive admin interface built with Rails Admin that provides full user management capabilities, system monitoring, and security features. This guide covers all administrative functions and best practices.

## Accessing the Admin Interface

### Prerequisites
- Admin role assignment (`role: :admin` in the User model)
- Valid user account with authentication

### Access URL
```
https://your-domain.com/admin
```

The admin interface is protected by:
- Authentication requirement (must be signed in)
- Authorization via Pundit (admin role required)
- Audit logging for all admin actions

## Main Features

### 1. Dashboard Overview

The admin dashboard provides:
- **System Health Status**: Real-time health indicator with color-coded status
- **User Statistics**: Total users, active users, locked users, suspended users
- **Activity Metrics**: Daily activities, suspicious activities, active sessions
- **Recent Activity Tables**: Admin actions and user registrations
- **System Metrics**: Error rates, response times, role distributions
- **Quick Actions**: Direct links to common admin tasks

### 2. User Management

#### User List View
- **Searchable Fields**: Email, full name, company, job title
- **Filters**: Role, creation date, suspension status, lock status
- **Sortable Columns**: All major fields with ascending/descending options
- **Pagination**: Configurable items per page (20, 50, 100)
- **Status Indicators**: Visual labels for account status

#### User Actions
- **View Details**: Comprehensive user profile information
- **Edit Profile**: Modify user information, role assignments
- **Suspend Account**: Temporarily disable user access with reason tracking
- **Unsuspend Account**: Restore suspended user access
- **Password Reset**: Force password changes (admin-initiated)
- **Bulk Operations**: Unlock multiple locked accounts simultaneously

#### User Profile Information
- Basic Information: Email, name, role, display name
- Profile Details: Bio, phone, company, job title, location, timezone
- Avatar Management: Image upload and display
- Email Preferences: Marketing emails, product updates, security alerts
- Account Status: Lock status, suspension status, timestamps
- Audit Trail: Who suspended/locked the account and when

### 3. Activity Monitoring

#### Activity Tracking
- **User Actions**: All user interactions with the system
- **Request Details**: IP addresses, user agents, device information
- **Response Metrics**: Status codes, response times
- **Suspicious Activity Detection**: Automated flagging of unusual patterns
- **Session Tracking**: Active sessions and session management

#### Activity Filters
- User-specific activities
- Action type filtering
- Controller and method filtering
- IP address tracking
- Suspicious activity isolation
- Time-based filtering
- Device and browser filtering

### 4. Security Features

#### Account Security
- **Automatic Locking**: Failed login attempt protection
- **Suspension System**: Admin-initiated account suspension
- **Session Management**: Active session monitoring and termination
- **IP Tracking**: Geographic and suspicious IP detection
- **Device Fingerprinting**: Browser and device identification

#### Audit Logging
- **Admin Actions**: All administrative actions are logged
- **Change Tracking**: Before/after values for modifications
- **IP and User Agent**: Request metadata for all admin actions
- **Timestamps**: Precise timing of all administrative activities
- **Data Integrity**: Immutable audit trail with JSON change details

### 5. System Maintenance

#### Automated Cleanup Operations
- **Old Activities**: Remove activity records older than 30 days
- **Expired Sessions**: Clean up expired user sessions
- **Old Audit Logs**: Archive audit logs older than 90 days
- **Full Cleanup**: Combined operation for all cleanup tasks

#### Maintenance Statistics
- Real-time counts of records eligible for cleanup
- Storage impact estimates
- Performance improvement projections
- Maintenance history tracking

#### Scheduled Maintenance
Available rake tasks for automation:
```bash
# Daily maintenance
rails daily_admin_maintenance

# Weekly maintenance  
rails weekly_admin_maintenance

# Monthly maintenance
rails monthly_admin_maintenance

# Individual operations
rails admin:cleanup_old_activities
rails admin:cleanup_expired_sessions
rails admin:cleanup_old_audit_logs
rails admin:full_cleanup
```

### 6. Reporting and Analytics

#### Health Monitoring
- **Error Rate Tracking**: Real-time error percentage monitoring
- **Response Time Analysis**: Average response time tracking
- **System Status**: Automated health status determination
- **Threshold Alerts**: Configurable warning and critical thresholds

#### Activity Reports
- **Daily Activity Reports**: Automated daily summaries
- **Weekly Summaries**: Comprehensive weekly analytics
- **Suspicious Activity Alerts**: Real-time security notifications
- **System Health Alerts**: Performance and error monitoring

#### Email Notifications
Automated email reports for administrators:
- Daily activity summaries
- Security alerts for suspicious activities
- System maintenance reports
- User account status changes
- Weekly performance summaries

## Admin Policies and Permissions

### Authorization Model (via Pundit)
All admin actions are controlled by the `RailsAdminPolicy`:
- Dashboard access
- Model viewing and editing
- Data export capabilities
- Bulk operations
- Custom actions (suspend, unsuspend, maintenance)

### Permission Requirements
- `user.admin?` must return `true` for all admin access
- Individual action authorization through Pundit policies
- Request-based authorization for sensitive operations
- IP and session validation for admin actions

## Security Best Practices

### Admin Account Security
1. **Strong Passwords**: Enforce complex password requirements
2. **Regular Access Review**: Periodic audit of admin user accounts
3. **Session Management**: Automatic timeout and secure session handling
4. **Two-Factor Authentication**: Recommended for admin accounts
5. **IP Restrictions**: Consider IP whitelisting for admin access

### Data Protection
1. **Audit Logging**: All admin actions are permanently logged
2. **Change Tracking**: Complete before/after change documentation
3. **Sensitive Data Filtering**: Passwords and tokens excluded from logs
4. **Backup Verification**: Regular backup testing and validation
5. **Data Retention**: Automated cleanup with retention policies

### Monitoring and Alerting
1. **Real-time Monitoring**: Continuous system health monitoring
2. **Threshold-based Alerts**: Automated alerts for performance issues
3. **Security Monitoring**: Suspicious activity detection and alerting
4. **Admin Activity Monitoring**: Oversight of administrative actions
5. **Regular Reporting**: Scheduled reports for system oversight

## API Access and Integration

### Rails Admin API
The system provides programmatic access through Rails Admin's built-in API:
- User management operations
- Activity data export
- System health metrics
- Maintenance operation triggers

### Custom Extensions
The admin interface can be extended with:
- Custom actions for specific business needs
- Additional model configurations
- Enhanced reporting capabilities
- Integration with external monitoring tools

## Troubleshooting

### Common Issues

#### Admin Access Problems
1. **403 Forbidden**: Check user role assignment (`user.admin?`)
2. **Redirect Loops**: Verify Pundit policy configuration
3. **CSS/JS Issues**: Ensure asset compilation is working
4. **Database Errors**: Check Rails Admin model configurations

#### Performance Issues
1. **Slow Loading**: Review database indexes on filtered fields
2. **Memory Usage**: Monitor large data exports and pagination
3. **Session Timeouts**: Adjust session timeout configurations
4. **Large Datasets**: Implement appropriate pagination limits

#### Security Concerns
1. **Failed Logins**: Review authentication logs and IP restrictions
2. **Suspicious Activity**: Investigate flagged activities immediately
3. **Admin Access Logs**: Regular review of admin audit trails
4. **System Health**: Monitor error rates and response times

### Maintenance Commands

#### System Health Checks
```bash
# Check overall system health
rails admin:check_system_health

# Generate activity report
rails admin:generate_activity_report

# Send daily report to admins
rails admin:send_daily_report
```

#### Database Maintenance
```bash
# Check cleanup statistics
rails console
> Activity.where("occurred_at < ?", 30.days.ago).count
> Session.expired.count
> AdminAuditLog.where("created_at < ?", 90.days.ago).count

# Manual cleanup operations
rails admin:cleanup_old_activities
rails admin:cleanup_expired_sessions
rails admin:cleanup_old_audit_logs
```

## Configuration

### Environment Variables
```bash
# Admin email settings
ADMIN_EMAIL_FROM=admin@your-domain.com
ADMIN_ALERT_RECIPIENTS=admin1@domain.com,admin2@domain.com

# System monitoring thresholds
SYSTEM_ERROR_THRESHOLD=5.0
SYSTEM_CRITICAL_THRESHOLD=10.0
SUSPICIOUS_ACTIVITY_THRESHOLD=10

# Data retention policies
ACTIVITY_RETENTION_DAYS=30
AUDIT_LOG_RETENTION_DAYS=90
SESSION_CLEANUP_ENABLED=true
```

### Rails Admin Configuration
Key configuration options in `config/initializers/rails_admin.rb`:
- Model inclusion and exclusion
- Action permissions and visibility
- Custom action definitions
- Field configurations and display options
- Authentication and authorization settings

## Support and Maintenance

### Regular Maintenance Schedule
- **Daily**: Session cleanup, health checks, daily reports
- **Weekly**: Activity cleanup review, performance analysis
- **Monthly**: Full system cleanup, audit log archival
- **Quarterly**: Admin access review, security audit

### Support Contacts
- System Administrator: [admin@your-domain.com]
- Security Team: [security@your-domain.com]
- Technical Support: [support@your-domain.com]

---

For additional information or support, please contact the system administrator or refer to the Rails Admin documentation at https://github.com/railsadminteam/rails_admin.