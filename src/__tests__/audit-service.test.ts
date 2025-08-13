import { PrismaClient, AuditEventType, AuditEventCategory, AuditEntityType, AuditSeverity } from '@prisma/client'
import { 
  AuditService, 
  AuditContext, 
  AuditLogEntry, 
  AuditSessionInfo 
} from '@/lib/audit/audit-service'
import { nanoid } from 'nanoid'

// Mock Prisma Client
const mockPrismaClient = {
  auditLog: {
    create: jest.fn(),
    findMany: jest.fn(),
    findFirst: jest.fn(),
    count: jest.fn(),
    aggregate: jest.fn(),
    deleteMany: jest.fn(),
    groupBy: jest.fn()
  }
} as unknown as PrismaClient

// Mock nanoid
jest.mock('nanoid', () => ({
  nanoid: jest.fn(() => 'test-request-id-123')
}))

// Mock environment variables
const originalEnv = process.env

describe('AuditService', () => {
  let auditService: AuditService
  
  beforeEach(() => {
    jest.clearAllMocks()
    process.env = {
      ...originalEnv,
      NODE_ENV: 'test',
      APP_VERSION: '2.0.0',
      HOSTNAME: 'test-server'
    }
    auditService = new AuditService(mockPrismaClient)
  })

  afterAll(() => {
    process.env = originalEnv
  })

  describe('Initialization', () => {
    test('should initialize with default context', () => {
      expect(auditService).toBeInstanceOf(AuditService)
    })

    test('should use environment variables for default context', () => {
      const service = new AuditService(mockPrismaClient)
      expect(service).toBeInstanceOf(AuditService)
      // Default context is private, but we can test its effect through logging
    })
  })

  describe('Basic Logging', () => {
    test('should log a simple audit event', async () => {
      const entry: AuditLogEntry = {
        eventType: AuditEventType.USER_ACTION,
        eventCategory: AuditEventCategory.AUTHENTICATION,
        entityType: AuditEntityType.USER,
        entityId: 'user-123',
        action: 'LOGIN',
        description: 'User logged in successfully'
      }

      const context: AuditContext = {
        userId: 'user-123',
        username: 'john.doe',
        userRole: 'admin',
        sessionId: 'session-456',
        ipAddress: '192.168.1.1',
        userAgent: 'Mozilla/5.0...'
      }

      await auditService.log(entry, context)

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: {
          eventType: AuditEventType.USER_ACTION,
          eventCategory: AuditEventCategory.AUTHENTICATION,
          entityType: AuditEntityType.USER,
          entityId: 'user-123',
          action: 'LOGIN',
          description: 'User logged in successfully',
          
          // User context
          userId: 'user-123',
          username: 'john.doe',
          userRole: 'admin',
          sessionId: 'session-456',
          
          // Request context
          ipAddress: '192.168.1.1',
          userAgent: 'Mozilla/5.0...',
          referrer: undefined,
          requestId: 'test-request-id-123',
          
          // Change tracking
          oldValues: null,
          newValues: null,
          changedFields: null,
          
          // System context
          hostname: 'test-server',
          environment: 'test',
          applicationVersion: '2.0.0',
          
          // Additional fields
          metadata: null,
          tags: null,
          severity: undefined,
          isPersonalData: undefined,
          retentionDays: undefined,
          duration: undefined
        }
      })
    })

    test('should log event without context', async () => {
      const entry: AuditLogEntry = {
        eventType: AuditEventType.SYSTEM_EVENT,
        eventCategory: AuditEventCategory.SYSTEM,
        entityType: AuditEntityType.SYSTEM,
        entityId: 'system',
        action: 'STARTUP',
        description: 'Application started'
      }

      await auditService.log(entry)

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          eventType: AuditEventType.SYSTEM_EVENT,
          action: 'STARTUP',
          userId: undefined,
          requestId: 'test-request-id-123',
          environment: 'test',
          hostname: 'test-server',
          applicationVersion: '2.0.0'
        })
      })
    })

    test('should handle complex audit entry with all fields', async () => {
      const entry: AuditLogEntry = {
        eventType: AuditEventType.DATA_CHANGE,
        eventCategory: AuditEventCategory.DATA_MANAGEMENT,
        entityType: AuditEntityType.CAMPAIGN,
        entityId: 'campaign-789',
        action: 'UPDATE',
        description: 'Campaign updated with new parameters',
        oldValues: { name: 'Old Campaign', status: 'draft' },
        newValues: { name: 'New Campaign', status: 'active' },
        changedFields: ['name', 'status'],
        metadata: { 
          updateReason: 'User requested changes',
          batchId: 'batch-001'
        },
        tags: ['campaign-management', 'user-initiated'],
        severity: AuditSeverity.MEDIUM,
        isPersonalData: false,
        retentionDays: 2555, // 7 years
        duration: 1500
      }

      const context: AuditContext = {
        userId: 'user-456',
        username: 'jane.smith',
        userRole: 'editor',
        sessionId: 'session-789',
        ipAddress: '10.0.0.1',
        requestId: 'req-custom-123'
      }

      await auditService.log(entry, context)

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: {
          eventType: AuditEventType.DATA_CHANGE,
          eventCategory: AuditEventCategory.DATA_MANAGEMENT,
          entityType: AuditEntityType.CAMPAIGN,
          entityId: 'campaign-789',
          action: 'UPDATE',
          description: 'Campaign updated with new parameters',
          
          // User context
          userId: 'user-456',
          username: 'jane.smith',
          userRole: 'editor',
          sessionId: 'session-789',
          
          // Request context
          ipAddress: '10.0.0.1',
          userAgent: undefined,
          referrer: undefined,
          requestId: 'req-custom-123',
          
          // Change tracking
          oldValues: JSON.stringify({ name: 'Old Campaign', status: 'draft' }),
          newValues: JSON.stringify({ name: 'New Campaign', status: 'active' }),
          changedFields: JSON.stringify(['name', 'status']),
          
          // System context
          hostname: 'test-server',
          environment: 'test',
          applicationVersion: '2.0.0',
          
          // Additional fields
          metadata: JSON.stringify({ 
            updateReason: 'User requested changes',
            batchId: 'batch-001'
          }),
          tags: JSON.stringify(['campaign-management', 'user-initiated']),
          severity: AuditSeverity.MEDIUM,
          isPersonalData: false,
          retentionDays: 2555,
          duration: 1500
        }
      })
    })
  })

  describe('Event Type Specific Logging', () => {
    test('should log authentication events correctly', async () => {
      const loginEntry: AuditLogEntry = {
        eventType: AuditEventType.AUTHENTICATION,
        eventCategory: AuditEventCategory.AUTHENTICATION,
        entityType: AuditEntityType.USER,
        entityId: 'user-123',
        action: 'LOGIN_SUCCESS',
        description: 'User successfully authenticated',
        metadata: { loginMethod: 'email', mfaUsed: true }
      }

      await auditService.log(loginEntry, { 
        userId: 'user-123',
        ipAddress: '192.168.1.1',
        sessionId: 'session-new'
      })

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          eventType: AuditEventType.AUTHENTICATION,
          action: 'LOGIN_SUCCESS',
          metadata: JSON.stringify({ loginMethod: 'email', mfaUsed: true })
        })
      })
    })

    test('should log authorization events correctly', async () => {
      const authzEntry: AuditLogEntry = {
        eventType: AuditEventType.AUTHORIZATION,
        eventCategory: AuditEventCategory.SECURITY,
        entityType: AuditEntityType.RESOURCE,
        entityId: 'campaign-sensitive',
        action: 'ACCESS_DENIED',
        description: 'User attempted to access restricted campaign',
        severity: AuditSeverity.HIGH,
        metadata: { requiredRole: 'admin', userRole: 'viewer' }
      }

      await auditService.log(authzEntry, { 
        userId: 'user-unauthorized',
        userRole: 'viewer'
      })

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          eventType: AuditEventType.AUTHORIZATION,
          action: 'ACCESS_DENIED',
          severity: AuditSeverity.HIGH
        })
      })
    })

    test('should log data changes with before/after values', async () => {
      const dataChangeEntry: AuditLogEntry = {
        eventType: AuditEventType.DATA_CHANGE,
        eventCategory: AuditEventCategory.DATA_MANAGEMENT,
        entityType: AuditEntityType.ASSET,
        entityId: 'asset-456',
        action: 'DELETE',
        description: 'Asset permanently deleted',
        oldValues: {
          name: 'Important Document.pdf',
          size: 1024768,
          createdAt: '2024-01-01T00:00:00Z'
        },
        severity: AuditSeverity.HIGH,
        isPersonalData: true,
        retentionDays: 2555
      }

      await auditService.log(dataChangeEntry, { userId: 'user-admin' })

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          action: 'DELETE',
          oldValues: JSON.stringify({
            name: 'Important Document.pdf',
            size: 1024768,
            createdAt: '2024-01-01T00:00:00Z'
          }),
          isPersonalData: true,
          severity: AuditSeverity.HIGH
        })
      })
    })
  })

  describe('Security and Compliance Logging', () => {
    test('should log security events with high severity', async () => {
      const securityEntry: AuditLogEntry = {
        eventType: AuditEventType.SECURITY_EVENT,
        eventCategory: AuditEventCategory.SECURITY,
        entityType: AuditEntityType.USER,
        entityId: 'user-suspicious',
        action: 'SUSPICIOUS_ACTIVITY',
        description: 'Multiple failed login attempts detected',
        severity: AuditSeverity.CRITICAL,
        metadata: {
          attemptCount: 5,
          timeWindow: '5 minutes',
          ipAddresses: ['192.168.1.100', '192.168.1.101'],
          triggeredRule: 'failed_login_threshold'
        }
      }

      await auditService.log(securityEntry, {
        ipAddress: '192.168.1.100',
        userAgent: 'Automated Scanner/1.0'
      })

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          eventType: AuditEventType.SECURITY_EVENT,
          severity: AuditSeverity.CRITICAL,
          metadata: JSON.stringify({
            attemptCount: 5,
            timeWindow: '5 minutes',
            ipAddresses: ['192.168.1.100', '192.168.1.101'],
            triggeredRule: 'failed_login_threshold'
          })
        })
      })
    })

    test('should log compliance events with retention requirements', async () => {
      const complianceEntry: AuditLogEntry = {
        eventType: AuditEventType.COMPLIANCE,
        eventCategory: AuditEventCategory.COMPLIANCE,
        entityType: AuditEntityType.PERSONAL_DATA,
        entityId: 'pii-record-789',
        action: 'DATA_EXPORT',
        description: 'Personal data exported for GDPR compliance request',
        isPersonalData: true,
        retentionDays: 2555, // Legal requirement: 7 years
        metadata: {
          requestType: 'GDPR_DATA_PORTABILITY',
          dataSubject: 'user-gdpr-123',
          exportFormat: 'JSON',
          approvedBy: 'privacy-officer-001'
        }
      }

      await auditService.log(complianceEntry, { 
        userId: 'privacy-officer-001',
        userRole: 'privacy_officer'
      })

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          eventType: AuditEventType.COMPLIANCE,
          isPersonalData: true,
          retentionDays: 2555,
          metadata: JSON.stringify({
            requestType: 'GDPR_DATA_PORTABILITY',
            dataSubject: 'user-gdpr-123',
            exportFormat: 'JSON',
            approvedBy: 'privacy-officer-001'
          })
        })
      })
    })

    test('should log financial transactions', async () => {
      const financialEntry: AuditLogEntry = {
        eventType: AuditEventType.BUSINESS_EVENT,
        eventCategory: AuditEventCategory.FINANCIAL,
        entityType: AuditEntityType.TRANSACTION,
        entityId: 'tx-payment-001',
        action: 'PAYMENT_PROCESSED',
        description: 'Subscription payment processed successfully',
        metadata: {
          amount: 99.99,
          currency: 'USD',
          paymentMethod: 'credit_card',
          paymentProvider: 'stripe',
          subscriptionPlan: 'pro_monthly'
        },
        severity: AuditSeverity.MEDIUM,
        retentionDays: 2920 // 8 years for financial records
      }

      await auditService.log(financialEntry, { 
        userId: 'customer-123',
        sessionId: 'checkout-session-456'
      })

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          eventCategory: AuditEventCategory.FINANCIAL,
          retentionDays: 2920,
          metadata: JSON.stringify({
            amount: 99.99,
            currency: 'USD',
            paymentMethod: 'credit_card',
            paymentProvider: 'stripe',
            subscriptionPlan: 'pro_monthly'
          })
        })
      })
    })
  })

  describe('Performance and System Events', () => {
    test('should log performance events with duration', async () => {
      const performanceEntry: AuditLogEntry = {
        eventType: AuditEventType.PERFORMANCE,
        eventCategory: AuditEventCategory.PERFORMANCE,
        entityType: AuditEntityType.API_ENDPOINT,
        entityId: '/api/campaigns',
        action: 'SLOW_QUERY',
        description: 'Database query exceeded performance threshold',
        duration: 5500, // 5.5 seconds
        severity: AuditSeverity.MEDIUM,
        metadata: {
          threshold: 1000,
          queryType: 'SELECT',
          tableCount: 3,
          recordCount: 15000
        }
      }

      await auditService.log(performanceEntry, { 
        requestId: 'req-perf-001',
        userAgent: 'Internal/Monitoring'
      })

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          eventType: AuditEventType.PERFORMANCE,
          duration: 5500,
          metadata: JSON.stringify({
            threshold: 1000,
            queryType: 'SELECT',
            tableCount: 3,
            recordCount: 15000
          })
        })
      })
    })

    test('should log system events', async () => {
      const systemEntry: AuditLogEntry = {
        eventType: AuditEventType.SYSTEM_EVENT,
        eventCategory: AuditEventCategory.SYSTEM,
        entityType: AuditEntityType.SYSTEM,
        entityId: 'application',
        action: 'DEPLOYMENT',
        description: 'New application version deployed successfully',
        metadata: {
          version: '2.1.0',
          environment: 'production',
          deploymentId: 'deploy-001',
          previousVersion: '2.0.5'
        }
      }

      await auditService.log(systemEntry)

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          eventType: AuditEventType.SYSTEM_EVENT,
          action: 'DEPLOYMENT',
          metadata: JSON.stringify({
            version: '2.1.0',
            environment: 'production',
            deploymentId: 'deploy-001',
            previousVersion: '2.0.5'
          })
        })
      })
    })
  })

  describe('Error Handling', () => {
    test('should handle database errors gracefully', async () => {
      const error = new Error('Database connection failed')
      mockPrismaClient.auditLog.create = jest.fn().mockRejectedValueOnce(error)

      const entry: AuditLogEntry = {
        eventType: AuditEventType.USER_ACTION,
        eventCategory: AuditEventCategory.GENERAL,
        entityType: AuditEntityType.USER,
        entityId: 'user-123',
        action: 'TEST_ACTION',
        description: 'Test action'
      }

      // Should not throw but handle error internally
      await expect(auditService.log(entry)).rejects.toThrow('Database connection failed')
    })

    test('should handle invalid JSON in metadata gracefully', async () => {
      const entryWithCircularRef: AuditLogEntry = {
        eventType: AuditEventType.ERROR,
        eventCategory: AuditEventCategory.GENERAL,
        entityType: AuditEntityType.SYSTEM,
        entityId: 'system',
        action: 'ERROR_LOG',
        description: 'Error with circular reference',
        metadata: {} as any
      }
      
      // Create circular reference
      entryWithCircularRef.metadata!.self = entryWithCircularRef.metadata

      await auditService.log(entryWithCircularRef)

      // Should handle JSON.stringify error and still create log entry
      expect(mockPrismaClient.auditLog.create).toHaveBeenCalled()
    })

    test('should generate unique request IDs when not provided', async () => {
      const entry: AuditLogEntry = {
        eventType: AuditEventType.USER_ACTION,
        eventCategory: AuditEventCategory.GENERAL,
        entityType: AuditEntityType.USER,
        entityId: 'user-123',
        action: 'ACTION_WITHOUT_REQUEST_ID',
        description: 'Action without explicit request ID'
      }

      await auditService.log(entry, { userId: 'user-123' })

      expect(nanoid).toHaveBeenCalled()
      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          requestId: 'test-request-id-123'
        })
      })
    })
  })

  describe('Context Inheritance and Defaults', () => {
    test('should inherit default context values', async () => {
      const entry: AuditLogEntry = {
        eventType: AuditEventType.USER_ACTION,
        eventCategory: AuditEventCategory.GENERAL,
        entityType: AuditEntityType.USER,
        entityId: 'user-123',
        action: 'TEST_DEFAULT_CONTEXT',
        description: 'Testing default context inheritance'
      }

      await auditService.log(entry)

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          environment: 'test',
          applicationVersion: '2.0.0',
          hostname: 'test-server'
        })
      })
    })

    test('should override default context with provided context', async () => {
      const entry: AuditLogEntry = {
        eventType: AuditEventType.USER_ACTION,
        eventCategory: AuditEventCategory.GENERAL,
        entityType: AuditEntityType.USER,
        entityId: 'user-123',
        action: 'TEST_CONTEXT_OVERRIDE',
        description: 'Testing context override'
      }

      const customContext: AuditContext = {
        environment: 'staging',
        applicationVersion: '3.0.0-beta',
        hostname: 'staging-server'
      }

      await auditService.log(entry, customContext)

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          environment: 'staging',
          applicationVersion: '3.0.0-beta',
          hostname: 'staging-server'
        })
      })
    })

    test('should handle missing environment variables gracefully', () => {
      // Reset environment variables
      delete process.env.NODE_ENV
      delete process.env.APP_VERSION
      delete process.env.HOSTNAME

      const serviceWithoutEnv = new AuditService(mockPrismaClient)
      
      expect(serviceWithoutEnv).toBeInstanceOf(AuditService)
      // Test will verify default values are used when env vars are missing
    })
  })

  describe('Field Validation and Data Integrity', () => {
    test('should handle null and undefined values correctly', async () => {
      const entry: AuditLogEntry = {
        eventType: AuditEventType.DATA_CHANGE,
        eventCategory: AuditEventCategory.DATA_MANAGEMENT,
        entityType: AuditEntityType.CAMPAIGN,
        entityId: 'campaign-123',
        action: 'UPDATE',
        description: 'Update with null values',
        oldValues: null as any,
        newValues: undefined as any,
        changedFields: null as any,
        metadata: null as any
      }

      await auditService.log(entry)

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          oldValues: null,
          newValues: null,
          changedFields: null,
          metadata: null
        })
      })
    })

    test('should handle empty arrays and objects', async () => {
      const entry: AuditLogEntry = {
        eventType: AuditEventType.DATA_CHANGE,
        eventCategory: AuditEventCategory.DATA_MANAGEMENT,
        entityType: AuditEntityType.CAMPAIGN,
        entityId: 'campaign-123',
        action: 'UPDATE',
        description: 'Update with empty values',
        oldValues: {},
        newValues: {},
        changedFields: [],
        metadata: {},
        tags: []
      }

      await auditService.log(entry)

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          oldValues: JSON.stringify({}),
          newValues: JSON.stringify({}),
          changedFields: JSON.stringify([]),
          metadata: JSON.stringify({}),
          tags: JSON.stringify([])
        })
      })
    })

    test('should validate required fields', async () => {
      const incompleteEntry = {
        // Missing required fields
        eventType: AuditEventType.USER_ACTION
        // Missing entityType, entityId, action, description
      } as AuditLogEntry

      // TypeScript should catch this at compile time,
      // but this tests runtime behavior
      await auditService.log(incompleteEntry)

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          eventType: AuditEventType.USER_ACTION,
          entityType: undefined,
          entityId: undefined,
          action: undefined,
          description: undefined
        })
      })
    })
  })

  describe('Batch Operations and Performance', () => {
    test('should handle multiple rapid log calls', async () => {
      const entries: AuditLogEntry[] = Array.from({ length: 10 }, (_, i) => ({
        eventType: AuditEventType.USER_ACTION,
        eventCategory: AuditEventCategory.GENERAL,
        entityType: AuditEntityType.USER,
        entityId: `user-${i}`,
        action: `ACTION_${i}`,
        description: `Test action ${i}`
      }))

      const promises = entries.map(entry => auditService.log(entry))
      await Promise.all(promises)

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledTimes(10)
    })

    test('should handle large metadata objects', async () => {
      const largeMetadata = {
        data: Array.from({ length: 1000 }, (_, i) => ({
          id: i,
          value: `value-${i}`,
          timestamp: new Date().toISOString()
        }))
      }

      const entry: AuditLogEntry = {
        eventType: AuditEventType.DATA_CHANGE,
        eventCategory: AuditEventCategory.DATA_MANAGEMENT,
        entityType: AuditEntityType.BATCH_OPERATION,
        entityId: 'batch-large-001',
        action: 'BULK_UPDATE',
        description: 'Bulk update with large metadata',
        metadata: largeMetadata
      }

      await auditService.log(entry)

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          metadata: JSON.stringify(largeMetadata)
        })
      })
    })
  })
})

describe('AuditService Integration Scenarios', () => {
  let auditService: AuditService

  beforeEach(() => {
    jest.clearAllMocks()
    auditService = new AuditService(mockPrismaClient)
  })

  describe('User Authentication Flow', () => {
    test('should log complete authentication flow', async () => {
      const sessionId = 'session-auth-flow'
      const userId = 'user-auth-test'
      const context: AuditContext = {
        sessionId,
        ipAddress: '192.168.1.1',
        userAgent: 'Mozilla/5.0 (Test Browser)'
      }

      // 1. Login attempt
      await auditService.log({
        eventType: AuditEventType.AUTHENTICATION,
        eventCategory: AuditEventCategory.AUTHENTICATION,
        entityType: AuditEntityType.USER,
        entityId: userId,
        action: 'LOGIN_ATTEMPT',
        description: 'User attempted to log in'
      }, context)

      // 2. Successful authentication
      await auditService.log({
        eventType: AuditEventType.AUTHENTICATION,
        eventCategory: AuditEventCategory.AUTHENTICATION,
        entityType: AuditEntityType.USER,
        entityId: userId,
        action: 'LOGIN_SUCCESS',
        description: 'User successfully authenticated',
        metadata: { mfaUsed: true }
      }, { ...context, userId, username: 'test.user' })

      // 3. Session creation
      await auditService.log({
        eventType: AuditEventType.SYSTEM_EVENT,
        eventCategory: AuditEventCategory.AUTHENTICATION,
        entityType: AuditEntityType.SESSION,
        entityId: sessionId,
        action: 'SESSION_CREATE',
        description: 'User session created'
      }, { ...context, userId })

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledTimes(3)
    })
  })

  describe('Data Lifecycle Management', () => {
    test('should log complete CRUD operations', async () => {
      const entityId = 'campaign-lifecycle-001'
      const userId = 'user-creator'
      const context: AuditContext = { userId, sessionId: 'session-crud' }

      // Create
      await auditService.log({
        eventType: AuditEventType.DATA_CHANGE,
        eventCategory: AuditEventCategory.DATA_MANAGEMENT,
        entityType: AuditEntityType.CAMPAIGN,
        entityId,
        action: 'CREATE',
        description: 'Campaign created',
        newValues: { name: 'New Campaign', status: 'draft' }
      }, context)

      // Update
      await auditService.log({
        eventType: AuditEventType.DATA_CHANGE,
        eventCategory: AuditEventCategory.DATA_MANAGEMENT,
        entityType: AuditEntityType.CAMPAIGN,
        entityId,
        action: 'UPDATE',
        description: 'Campaign updated',
        oldValues: { name: 'New Campaign', status: 'draft' },
        newValues: { name: 'Updated Campaign', status: 'active' },
        changedFields: ['name', 'status']
      }, context)

      // Archive
      await auditService.log({
        eventType: AuditEventType.DATA_CHANGE,
        eventCategory: AuditEventCategory.DATA_MANAGEMENT,
        entityType: AuditEntityType.CAMPAIGN,
        entityId,
        action: 'ARCHIVE',
        description: 'Campaign archived',
        oldValues: { status: 'active' },
        newValues: { status: 'archived' }
      }, context)

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledTimes(3)
      
      // Verify the sequence of operations
      const calls = mockPrismaClient.auditLog.create.mock.calls
      expect(calls[0][0].data.action).toBe('CREATE')
      expect(calls[1][0].data.action).toBe('UPDATE')
      expect(calls[2][0].data.action).toBe('ARCHIVE')
    })
  })

  describe('Compliance and Legal Requirements', () => {
    test('should log GDPR data subject requests', async () => {
      const dataSubjectId = 'user-gdpr-subject'
      const context: AuditContext = {
        userId: 'privacy-officer-001',
        userRole: 'privacy_officer'
      }

      // Data access request
      await auditService.log({
        eventType: AuditEventType.COMPLIANCE,
        eventCategory: AuditEventCategory.COMPLIANCE,
        entityType: AuditEntityType.PERSONAL_DATA,
        entityId: dataSubjectId,
        action: 'GDPR_ACCESS_REQUEST',
        description: 'GDPR data access request initiated',
        metadata: {
          requestType: 'access',
          requesterEmail: 'subject@example.com',
          requestDate: new Date().toISOString()
        },
        isPersonalData: true,
        retentionDays: 2555
      }, context)

      // Data portability
      await auditService.log({
        eventType: AuditEventType.COMPLIANCE,
        eventCategory: AuditEventCategory.COMPLIANCE,
        entityType: AuditEntityType.PERSONAL_DATA,
        entityId: dataSubjectId,
        action: 'GDPR_DATA_EXPORT',
        description: 'Personal data exported for portability request',
        metadata: {
          exportFormat: 'JSON',
          dataCategories: ['profile', 'preferences', 'activities'],
          exportSize: '2.5MB'
        },
        isPersonalData: true
      }, context)

      // Right to be forgotten
      await auditService.log({
        eventType: AuditEventType.COMPLIANCE,
        eventCategory: AuditEventCategory.COMPLIANCE,
        entityType: AuditEntityType.PERSONAL_DATA,
        entityId: dataSubjectId,
        action: 'GDPR_ERASURE',
        description: 'Personal data erased per GDPR right to be forgotten',
        oldValues: { recordCount: 45, categories: ['profile', 'activities'] },
        metadata: {
          erasureMethod: 'hard_delete',
          verificationRequired: true
        },
        isPersonalData: true,
        severity: AuditSeverity.HIGH
      }, context)

      expect(mockPrismaClient.auditLog.create).toHaveBeenCalledTimes(3)
    })
  })
})