import { NotificationType, NotificationCategory } from '@prisma/client'

export interface EmailTemplate {
  id: string
  name: string
  type: NotificationType
  category: NotificationCategory
  subject: string
  htmlContent: string
  textContent: string
  placeholders: string[]
  isActive: boolean
  language: string
}

export interface EmailTemplateData {
  recipientName?: string
  recipientEmail?: string
  senderName?: string
  title?: string
  message?: string
  actionUrl?: string
  actionText?: string
  entityTitle?: string
  entityType?: string
  companyName?: string
  unsubscribeUrl?: string
  preferencesUrl?: string
  supportUrl?: string
  logoUrl?: string
  [key: string]: any
}

export class EmailTemplateEngine {
  private templates: Map<string, EmailTemplate> = new Map()

  constructor() {
    this.initializeDefaultTemplates()
  }

  /**
   * Render an email template with provided data
   */
  render(templateId: string, data: EmailTemplateData): { subject: string; html: string; text: string } {
    const template = this.templates.get(templateId)
    if (!template) {
      throw new Error(`Template ${templateId} not found`)
    }

    const processedData = this.processData(data)

    return {
      subject: this.replacePlaceholders(template.subject, processedData),
      html: this.replacePlaceholders(template.htmlContent, processedData),
      text: this.replacePlaceholders(template.textContent, processedData)
    }
  }

  /**
   * Get template by type and category
   */
  getTemplate(type: NotificationType, category: NotificationCategory, language = 'en'): EmailTemplate | null {
    const templateId = `${type}_${category}_${language}`
    return this.templates.get(templateId) || this.templates.get(`${type}_${category}_en`) || null
  }

  /**
   * Add or update a template
   */
  setTemplate(template: EmailTemplate): void {
    this.templates.set(template.id, template)
  }

  /**
   * Replace placeholders in content
   */
  private replacePlaceholders(content: string, data: EmailTemplateData): string {
    return content.replace(/\{\{(\w+)\}\}/g, (match, key) => {
      return data[key] !== undefined ? String(data[key]) : match
    })
  }

  /**
   * Process and enhance template data
   */
  private processData(data: EmailTemplateData): EmailTemplateData {
    const baseUrl = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'
    
    return {
      companyName: 'Marketer Gen',
      logoUrl: `${baseUrl}/logo.png`,
      unsubscribeUrl: `${baseUrl}/unsubscribe`,
      preferencesUrl: `${baseUrl}/notifications/preferences`,
      supportUrl: `${baseUrl}/support`,
      year: new Date().getFullYear().toString(),
      ...data
    }
  }

  /**
   * Initialize default email templates
   */
  private initializeDefaultTemplates(): void {
    // Mention notification template
    this.setTemplate({
      id: 'MENTION_COLLABORATION_en',
      name: 'Mention Notification',
      type: NotificationType.MENTION,
      category: NotificationCategory.COLLABORATION,
      subject: '{{senderName}} mentioned you in {{entityTitle}}',
      htmlContent: this.getMentionHtmlTemplate(),
      textContent: this.getMentionTextTemplate(),
      placeholders: ['recipientName', 'senderName', 'entityTitle', 'message', 'actionUrl', 'actionText'],
      isActive: true,
      language: 'en'
    })

    // Comment notification template
    this.setTemplate({
      id: 'COMMENT_COLLABORATION_en',
      name: 'Comment Notification',
      type: NotificationType.COMMENT,
      category: NotificationCategory.COLLABORATION,
      subject: 'New comment on {{entityTitle}}',
      htmlContent: this.getCommentHtmlTemplate(),
      textContent: this.getCommentTextTemplate(),
      placeholders: ['recipientName', 'senderName', 'entityTitle', 'message', 'actionUrl', 'actionText'],
      isActive: true,
      language: 'en'
    })

    // Assignment notification template
    this.setTemplate({
      id: 'ASSIGNMENT_COLLABORATION_en',
      name: 'Assignment Notification',
      type: NotificationType.ASSIGNMENT,
      category: NotificationCategory.COLLABORATION,
      subject: 'New assignment: {{title}}',
      htmlContent: this.getAssignmentHtmlTemplate(),
      textContent: this.getAssignmentTextTemplate(),
      placeholders: ['recipientName', 'senderName', 'title', 'message', 'dueDate', 'actionUrl', 'actionText'],
      isActive: true,
      language: 'en'
    })

    // Approval request template
    this.setTemplate({
      id: 'APPROVAL_REQUEST_APPROVAL_en',
      name: 'Approval Request Notification',
      type: NotificationType.APPROVAL_REQUEST,
      category: NotificationCategory.APPROVAL,
      subject: 'Approval needed: {{title}}',
      htmlContent: this.getApprovalRequestHtmlTemplate(),
      textContent: this.getApprovalRequestTextTemplate(),
      placeholders: ['recipientName', 'senderName', 'title', 'message', 'workflowName', 'actionUrl', 'actionText'],
      isActive: true,
      language: 'en'
    })

    // Approval response template
    this.setTemplate({
      id: 'APPROVAL_RESPONSE_APPROVAL_en',
      name: 'Approval Response Notification',
      type: NotificationType.APPROVAL_RESPONSE,
      category: NotificationCategory.APPROVAL,
      subject: '{{title}} has been {{action}}',
      htmlContent: this.getApprovalResponseHtmlTemplate(),
      textContent: this.getApprovalResponseTextTemplate(),
      placeholders: ['recipientName', 'senderName', 'title', 'action', 'comment', 'actionUrl', 'actionText'],
      isActive: true,
      language: 'en'
    })

    // Security alert template
    this.setTemplate({
      id: 'SECURITY_ALERT_SECURITY_en',
      name: 'Security Alert Notification',
      type: NotificationType.SECURITY_ALERT,
      category: NotificationCategory.SECURITY,
      subject: 'Security Alert: {{title}}',
      htmlContent: this.getSecurityAlertHtmlTemplate(),
      textContent: this.getSecurityAlertTextTemplate(),
      placeholders: ['recipientName', 'title', 'message', 'threatLevel', 'actionUrl', 'actionText'],
      isActive: true,
      language: 'en'
    })

    // Digest template
    this.setTemplate({
      id: 'DIGEST_SYSTEM_en',
      name: 'Daily Digest',
      type: NotificationType.DIGEST,
      category: NotificationCategory.SYSTEM,
      subject: 'Your daily digest - {{notificationCount}} notifications',
      htmlContent: this.getDigestHtmlTemplate(),
      textContent: this.getDigestTextTemplate(),
      placeholders: ['recipientName', 'notificationCount', 'notifications', 'period'],
      isActive: true,
      language: 'en'
    })
  }

  /**
   * HTML template for mention notifications
   */
  private getMentionHtmlTemplate(): string {
    return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{senderName}} mentioned you</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f5f5f5; }
    .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; }
    .header { background-color: #6366f1; color: white; padding: 20px; text-align: center; }
    .logo { font-size: 24px; font-weight: bold; }
    .content { padding: 30px; }
    .notification-card { background-color: #f8fafc; border-left: 4px solid #6366f1; padding: 20px; margin: 20px 0; border-radius: 4px; }
    .button { display: inline-block; background-color: #6366f1; color: white; text-decoration: none; padding: 12px 24px; border-radius: 6px; font-weight: 500; margin: 20px 0; }
    .footer { background-color: #f8fafc; padding: 20px; text-align: center; font-size: 14px; color: #64748b; }
    .footer a { color: #6366f1; text-decoration: none; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo">{{companyName}}</div>
    </div>
    
    <div class="content">
      <h1>Hi {{recipientName}},</h1>
      
      <p><strong>{{senderName}}</strong> mentioned you in <strong>{{entityTitle}}</strong>:</p>
      
      <div class="notification-card">
        <p>"{{message}}"</p>
      </div>
      
      <a href="{{actionUrl}}" class="button">{{actionText}}</a>
      
      <p>Stay connected and collaborate effectively with your team.</p>
    </div>
    
    <div class="footer">
      <p>
        <a href="{{preferencesUrl}}">Notification Preferences</a> | 
        <a href="{{unsubscribeUrl}}">Unsubscribe</a> | 
        <a href="{{supportUrl}}">Support</a>
      </p>
      <p>&copy; {{year}} {{companyName}}. All rights reserved.</p>
    </div>
  </div>
</body>
</html>`
  }

  /**
   * Text template for mention notifications
   */
  private getMentionTextTemplate(): string {
    return `Hi {{recipientName}},

{{senderName}} mentioned you in {{entityTitle}}:

"{{message}}"

{{actionText}}: {{actionUrl}}

Stay connected and collaborate effectively with your team.

---
Manage your notification preferences: {{preferencesUrl}}
Unsubscribe: {{unsubscribeUrl}}
Support: {{supportUrl}}

© {{year}} {{companyName}}. All rights reserved.`
  }

  /**
   * HTML template for comment notifications
   */
  private getCommentHtmlTemplate(): string {
    return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>New comment on {{entityTitle}}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f5f5f5; }
    .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; }
    .header { background-color: #10b981; color: white; padding: 20px; text-align: center; }
    .logo { font-size: 24px; font-weight: bold; }
    .content { padding: 30px; }
    .notification-card { background-color: #f0fdf4; border-left: 4px solid #10b981; padding: 20px; margin: 20px 0; border-radius: 4px; }
    .button { display: inline-block; background-color: #10b981; color: white; text-decoration: none; padding: 12px 24px; border-radius: 6px; font-weight: 500; margin: 20px 0; }
    .footer { background-color: #f8fafc; padding: 20px; text-align: center; font-size: 14px; color: #64748b; }
    .footer a { color: #10b981; text-decoration: none; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo">{{companyName}}</div>
    </div>
    
    <div class="content">
      <h1>Hi {{recipientName}},</h1>
      
      <p><strong>{{senderName}}</strong> left a new comment on <strong>{{entityTitle}}</strong>:</p>
      
      <div class="notification-card">
        <p>"{{message}}"</p>
      </div>
      
      <a href="{{actionUrl}}" class="button">{{actionText}}</a>
      
      <p>Keep the conversation going and stay engaged with your team.</p>
    </div>
    
    <div class="footer">
      <p>
        <a href="{{preferencesUrl}}">Notification Preferences</a> | 
        <a href="{{unsubscribeUrl}}">Unsubscribe</a> | 
        <a href="{{supportUrl}}">Support</a>
      </p>
      <p>&copy; {{year}} {{companyName}}. All rights reserved.</p>
    </div>
  </div>
</body>
</html>`
  }

  /**
   * Text template for comment notifications
   */
  private getCommentTextTemplate(): string {
    return `Hi {{recipientName}},

{{senderName}} left a new comment on {{entityTitle}}:

"{{message}}"

{{actionText}}: {{actionUrl}}

Keep the conversation going and stay engaged with your team.

---
Manage your notification preferences: {{preferencesUrl}}
Unsubscribe: {{unsubscribeUrl}}
Support: {{supportUrl}}

© {{year}} {{companyName}}. All rights reserved.`
  }

  /**
   * HTML template for assignment notifications
   */
  private getAssignmentHtmlTemplate(): string {
    return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>New assignment: {{title}}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f5f5f5; }
    .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; }
    .header { background-color: #f59e0b; color: white; padding: 20px; text-align: center; }
    .logo { font-size: 24px; font-weight: bold; }
    .content { padding: 30px; }
    .notification-card { background-color: #fffbeb; border-left: 4px solid #f59e0b; padding: 20px; margin: 20px 0; border-radius: 4px; }
    .button { display: inline-block; background-color: #f59e0b; color: white; text-decoration: none; padding: 12px 24px; border-radius: 6px; font-weight: 500; margin: 20px 0; }
    .footer { background-color: #f8fafc; padding: 20px; text-align: center; font-size: 14px; color: #64748b; }
    .footer a { color: #f59e0b; text-decoration: none; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo">{{companyName}}</div>
    </div>
    
    <div class="content">
      <h1>Hi {{recipientName}},</h1>
      
      <p><strong>{{senderName}}</strong> assigned you to a new task:</p>
      
      <div class="notification-card">
        <h3>{{title}}</h3>
        <p>{{message}}</p>
        {{#dueDate}}<p><strong>Due:</strong> {{dueDate}}</p>{{/dueDate}}
      </div>
      
      <a href="{{actionUrl}}" class="button">{{actionText}}</a>
      
      <p>Get started on your new assignment and deliver great results.</p>
    </div>
    
    <div class="footer">
      <p>
        <a href="{{preferencesUrl}}">Notification Preferences</a> | 
        <a href="{{unsubscribeUrl}}">Unsubscribe</a> | 
        <a href="{{supportUrl}}">Support</a>
      </p>
      <p>&copy; {{year}} {{companyName}}. All rights reserved.</p>
    </div>
  </div>
</body>
</html>`
  }

  /**
   * Text template for assignment notifications
   */
  private getAssignmentTextTemplate(): string {
    return `Hi {{recipientName}},

{{senderName}} assigned you to a new task:

{{title}}

{{message}}

{{#dueDate}}Due: {{dueDate}}{{/dueDate}}

{{actionText}}: {{actionUrl}}

Get started on your new assignment and deliver great results.

---
Manage your notification preferences: {{preferencesUrl}}
Unsubscribe: {{unsubscribeUrl}}
Support: {{supportUrl}}

© {{year}} {{companyName}}. All rights reserved.`
  }

  /**
   * HTML template for approval request notifications
   */
  private getApprovalRequestHtmlTemplate(): string {
    return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Approval needed: {{title}}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f5f5f5; }
    .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; }
    .header { background-color: #8b5cf6; color: white; padding: 20px; text-align: center; }
    .logo { font-size: 24px; font-weight: bold; }
    .content { padding: 30px; }
    .notification-card { background-color: #faf5ff; border-left: 4px solid #8b5cf6; padding: 20px; margin: 20px 0; border-radius: 4px; }
    .button { display: inline-block; background-color: #8b5cf6; color: white; text-decoration: none; padding: 12px 24px; border-radius: 6px; font-weight: 500; margin: 20px 0; }
    .urgent { background-color: #dc2626; }
    .footer { background-color: #f8fafc; padding: 20px; text-align: center; font-size: 14px; color: #64748b; }
    .footer a { color: #8b5cf6; text-decoration: none; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo">{{companyName}}</div>
    </div>
    
    <div class="content">
      <h1>Hi {{recipientName}},</h1>
      
      <p><strong>{{senderName}}</strong> submitted content for your approval:</p>
      
      <div class="notification-card">
        <h3>{{title}}</h3>
        <p>{{message}}</p>
        {{#workflowName}}<p><strong>Workflow:</strong> {{workflowName}}</p>{{/workflowName}}
      </div>
      
      <a href="{{actionUrl}}" class="button">{{actionText}}</a>
      
      <p>Your team is waiting for your review. Please approve or provide feedback as soon as possible.</p>
    </div>
    
    <div class="footer">
      <p>
        <a href="{{preferencesUrl}}">Notification Preferences</a> | 
        <a href="{{unsubscribeUrl}}">Unsubscribe</a> | 
        <a href="{{supportUrl}}">Support</a>
      </p>
      <p>&copy; {{year}} {{companyName}}. All rights reserved.</p>
    </div>
  </div>
</body>
</html>`
  }

  /**
   * Text template for approval request notifications
   */
  private getApprovalRequestTextTemplate(): string {
    return `Hi {{recipientName}},

{{senderName}} submitted content for your approval:

{{title}}

{{message}}

{{#workflowName}}Workflow: {{workflowName}}{{/workflowName}}

{{actionText}}: {{actionUrl}}

Your team is waiting for your review. Please approve or provide feedback as soon as possible.

---
Manage your notification preferences: {{preferencesUrl}}
Unsubscribe: {{unsubscribeUrl}}
Support: {{supportUrl}}

© {{year}} {{companyName}}. All rights reserved.`
  }

  /**
   * HTML template for approval response notifications
   */
  private getApprovalResponseHtmlTemplate(): string {
    return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{title}} has been {{action}}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f5f5f5; }
    .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; }
    .header { background-color: #059669; color: white; padding: 20px; text-align: center; }
    .header.rejected { background-color: #dc2626; }
    .logo { font-size: 24px; font-weight: bold; }
    .content { padding: 30px; }
    .notification-card { background-color: #ecfdf5; border-left: 4px solid #059669; padding: 20px; margin: 20px 0; border-radius: 4px; }
    .notification-card.rejected { background-color: #fef2f2; border-left-color: #dc2626; }
    .button { display: inline-block; background-color: #059669; color: white; text-decoration: none; padding: 12px 24px; border-radius: 6px; font-weight: 500; margin: 20px 0; }
    .footer { background-color: #f8fafc; padding: 20px; text-align: center; font-size: 14px; color: #64748b; }
    .footer a { color: #059669; text-decoration: none; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header {{#rejected}}rejected{{/rejected}}">
      <div class="logo">{{companyName}}</div>
    </div>
    
    <div class="content">
      <h1>Hi {{recipientName}},</h1>
      
      <p><strong>{{senderName}}</strong> has {{action}} your submission:</p>
      
      <div class="notification-card {{#rejected}}rejected{{/rejected}}">
        <h3>{{title}}</h3>
        {{#comment}}<p><strong>Comment:</strong> "{{comment}}"</p>{{/comment}}
      </div>
      
      <a href="{{actionUrl}}" class="button">{{actionText}}</a>
      
      <p>{{#approved}}Great work! Your content has been approved and is ready for the next step.{{/approved}}{{#rejected}}Please review the feedback and make the necessary changes.{{/rejected}}</p>
    </div>
    
    <div class="footer">
      <p>
        <a href="{{preferencesUrl}}">Notification Preferences</a> | 
        <a href="{{unsubscribeUrl}}">Unsubscribe</a> | 
        <a href="{{supportUrl}}">Support</a>
      </p>
      <p>&copy; {{year}} {{companyName}}. All rights reserved.</p>
    </div>
  </div>
</body>
</html>`
  }

  /**
   * Text template for approval response notifications
   */
  private getApprovalResponseTextTemplate(): string {
    return `Hi {{recipientName}},

{{senderName}} has {{action}} your submission:

{{title}}

{{#comment}}Comment: "{{comment}}"{{/comment}}

{{actionText}}: {{actionUrl}}

{{#approved}}Great work! Your content has been approved and is ready for the next step.{{/approved}}{{#rejected}}Please review the feedback and make the necessary changes.{{/rejected}}

---
Manage your notification preferences: {{preferencesUrl}}
Unsubscribe: {{unsubscribeUrl}}
Support: {{supportUrl}}

© {{year}} {{companyName}}. All rights reserved.`
  }

  /**
   * HTML template for security alert notifications
   */
  private getSecurityAlertHtmlTemplate(): string {
    return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Security Alert: {{title}}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f5f5f5; }
    .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; }
    .header { background-color: #dc2626; color: white; padding: 20px; text-align: center; }
    .logo { font-size: 24px; font-weight: bold; }
    .content { padding: 30px; }
    .alert-card { background-color: #fef2f2; border-left: 4px solid #dc2626; padding: 20px; margin: 20px 0; border-radius: 4px; }
    .button { display: inline-block; background-color: #dc2626; color: white; text-decoration: none; padding: 12px 24px; border-radius: 6px; font-weight: 500; margin: 20px 0; }
    .footer { background-color: #f8fafc; padding: 20px; text-align: center; font-size: 14px; color: #64748b; }
    .footer a { color: #dc2626; text-decoration: none; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo">{{companyName}} Security</div>
    </div>
    
    <div class="content">
      <h1>Security Alert</h1>
      
      <p>Hi {{recipientName}},</p>
      
      <div class="alert-card">
        <h3>{{title}}</h3>
        <p>{{message}}</p>
        {{#threatLevel}}<p><strong>Threat Level:</strong> {{threatLevel}}</p>{{/threatLevel}}
      </div>
      
      <a href="{{actionUrl}}" class="button">{{actionText}}</a>
      
      <p><strong>What to do:</strong></p>
      <ul>
        <li>Review the activity immediately</li>
        <li>Change your password if you don't recognize this activity</li>
        <li>Contact support if you need assistance</li>
      </ul>
      
      <p>If this was not you, please secure your account immediately.</p>
    </div>
    
    <div class="footer">
      <p>
        <a href="{{supportUrl}}">Contact Support</a> | 
        <a href="{{preferencesUrl}}">Notification Preferences</a>
      </p>
      <p>&copy; {{year}} {{companyName}}. All rights reserved.</p>
    </div>
  </div>
</body>
</html>`
  }

  /**
   * Text template for security alert notifications
   */
  private getSecurityAlertTextTemplate(): string {
    return `SECURITY ALERT

Hi {{recipientName}},

{{title}}

{{message}}

{{#threatLevel}}Threat Level: {{threatLevel}}{{/threatLevel}}

{{actionText}}: {{actionUrl}}

What to do:
- Review the activity immediately
- Change your password if you don't recognize this activity
- Contact support if you need assistance

If this was not you, please secure your account immediately.

---
Contact Support: {{supportUrl}}
Notification Preferences: {{preferencesUrl}}

© {{year}} {{companyName}}. All rights reserved.`
  }

  /**
   * HTML template for digest notifications
   */
  private getDigestHtmlTemplate(): string {
    return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Your {{period}} digest</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f5f5f5; }
    .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; }
    .header { background-color: #6366f1; color: white; padding: 20px; text-align: center; }
    .logo { font-size: 24px; font-weight: bold; }
    .content { padding: 30px; }
    .notification-item { background-color: #f8fafc; padding: 15px; margin: 10px 0; border-radius: 4px; border-left: 3px solid #6366f1; }
    .stats { display: flex; justify-content: space-around; background-color: #f1f5f9; padding: 20px; margin: 20px 0; border-radius: 6px; }
    .stat { text-align: center; }
    .stat-number { font-size: 24px; font-weight: bold; color: #6366f1; }
    .button { display: inline-block; background-color: #6366f1; color: white; text-decoration: none; padding: 12px 24px; border-radius: 6px; font-weight: 500; margin: 20px 0; }
    .footer { background-color: #f8fafc; padding: 20px; text-align: center; font-size: 14px; color: #64748b; }
    .footer a { color: #6366f1; text-decoration: none; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo">{{companyName}}</div>
    </div>
    
    <div class="content">
      <h1>Your {{period}} digest</h1>
      
      <p>Hi {{recipientName}},</p>
      
      <p>Here's a summary of your notifications from the past {{period}}:</p>
      
      <div class="stats">
        <div class="stat">
          <div class="stat-number">{{notificationCount}}</div>
          <div>Total Notifications</div>
        </div>
      </div>
      
      {{#notifications}}
      <div class="notification-item">
        <h4>{{title}}</h4>
        <p>{{message}}</p>
        <small>{{createdAt}} • {{type}}</small>
      </div>
      {{/notifications}}
      
      <a href="{{actionUrl}}" class="button">View All Notifications</a>
      
      <p>Stay on top of your work and never miss important updates.</p>
    </div>
    
    <div class="footer">
      <p>
        <a href="{{preferencesUrl}}">Notification Preferences</a> | 
        <a href="{{unsubscribeUrl}}">Unsubscribe</a> | 
        <a href="{{supportUrl}}">Support</a>
      </p>
      <p>&copy; {{year}} {{companyName}}. All rights reserved.</p>
    </div>
  </div>
</body>
</html>`
  }

  /**
   * Text template for digest notifications
   */
  private getDigestTextTemplate(): string {
    return `Your {{period}} digest

Hi {{recipientName}},

Here's a summary of your notifications from the past {{period}}:

Total Notifications: {{notificationCount}}

{{#notifications}}
- {{title}}
  {{message}}
  {{createdAt}} • {{type}}

{{/notifications}}

View all notifications: {{actionUrl}}

Stay on top of your work and never miss important updates.

---
Manage your notification preferences: {{preferencesUrl}}
Unsubscribe: {{unsubscribeUrl}}
Support: {{supportUrl}}

© {{year}} {{companyName}}. All rights reserved.`
  }
}

// Singleton instance
export const emailTemplateEngine = new EmailTemplateEngine()

export default EmailTemplateEngine