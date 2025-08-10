import { describe, it, expect } from 'vitest'
import { z } from 'zod'
import {
  emailSchema,
  passwordSchema,
  urlSchema,
  phoneSchema,
  campaignNameSchema,
  contentTitleSchema,
  contentDescriptionSchema,
  tagSchema,
  contentGenerationSchema,
  campaignSchema,
  userProfileSchema,
  loginSchema,
  registerSchema,
  templateSchema,
  type ContentGenerationFormData,
  type CampaignFormData,
  type UserProfileFormData,
  type LoginFormData,
  type RegisterFormData,
  type TemplateFormData,
} from '@/components/forms/schemas'

describe('Schema Validation Tests', () => {
  describe('Basic Field Schemas', () => {
    describe('emailSchema', () => {
      it('accepts valid email addresses', () => {
        const validEmails = [
          'user@example.com',
          'test.user@domain.co.uk',
          'user+tag@company.org',
          'firstname.lastname@subdomain.domain.com',
          'test123@test-domain.com',
        ]

        validEmails.forEach(email => {
          expect(() => emailSchema.parse(email)).not.toThrow()
          expect(emailSchema.parse(email)).toBe(email)
        })
      })

      it('rejects invalid email addresses', () => {
        const invalidEmails = [
          'invalid-email',
          '@domain.com',
          'user@',
          'user.domain.com',
          'user@domain',
          'user@@domain.com',
          'user @domain.com',
          '',
        ]

        invalidEmails.forEach(email => {
          expect(() => emailSchema.parse(email)).toThrow('Please enter a valid email address')
        })
      })
    })

    describe('passwordSchema', () => {
      it('accepts valid passwords', () => {
        const validPasswords = [
          'Password123!', // Has all requirements and ends with allowed chars
          'MySecure1@',    // Ends with allowed chars  
          'Complex9$',     // Ends with allowed chars
          'Strong1!',      // Ends with allowed chars
          'Test123@',      // Ends with allowed chars
        ]

        validPasswords.forEach(password => {
          expect(() => passwordSchema.parse(password)).not.toThrow()
          expect(passwordSchema.parse(password)).toBe(password)
        })
      })

      it('rejects passwords that are too short', () => {
        const shortPasswords = ['short', '1234567', 'Pass1!']

        shortPasswords.forEach(password => {
          expect(() => passwordSchema.parse(password)).toThrow('Password must be at least 8 characters')
        })
      })

      it('rejects passwords without uppercase letters', () => {
        const noUppercasePasswords = ['password123!', 'mypass1@', 'secure123#']

        noUppercasePasswords.forEach(password => {
          expect(() => passwordSchema.parse(password)).toThrow(/must contain.*uppercase/)
        })
      })

      it('rejects passwords without lowercase letters', () => {
        const noLowercasePasswords = ['PASSWORD123!', 'MYPASS1@', 'SECURE123#']

        noLowercasePasswords.forEach(password => {
          expect(() => passwordSchema.parse(password)).toThrow(/must contain.*lowercase/)
        })
      })

      it('rejects passwords without numbers', () => {
        const noNumberPasswords = ['Password!', 'MySecure@Pass', 'ComplexPass#']

        noNumberPasswords.forEach(password => {
          expect(() => passwordSchema.parse(password)).toThrow(/must contain.*number/)
        })
      })

      it('rejects passwords without special characters', () => {
        const noSpecialCharPasswords = ['Password123', 'MySecurePass1', 'ComplexPassword9']

        noSpecialCharPasswords.forEach(password => {
          expect(() => passwordSchema.parse(password)).toThrow(/must contain.*special character/)
        })
      })
    })

    describe('urlSchema', () => {
      it('accepts valid URLs', () => {
        const validUrls = [
          'https://example.com',
          'http://localhost:3000',
          'https://sub.domain.co.uk/path',
          'https://www.google.com/search?q=test',
          'https://api.stripe.com/v1/charges',
        ]

        validUrls.forEach(url => {
          expect(() => urlSchema.parse(url)).not.toThrow()
          expect(urlSchema.parse(url)).toBe(url)
        })
      })

      it('rejects invalid URLs', () => {
        const invalidUrls = [
          'not-a-url',
          'example.com',
          'www.example.com',
          'http://',
          '',
          'just-text',
        ]

        invalidUrls.forEach(url => {
          expect(() => urlSchema.parse(url)).toThrow('Please enter a valid URL')
        })
      })
    })

    describe('phoneSchema', () => {
      it('accepts valid phone numbers', () => {
        const validPhones = [
          '+1 234 567 8900',
          '(234) 567-8900',
          '234-567-8900',
          '2345678900',
          '+1 (555) 123-4567',
          '555 123 4567',
        ]

        validPhones.forEach(phone => {
          expect(() => phoneSchema.parse(phone)).not.toThrow()
          expect(phoneSchema.parse(phone)).toBe(phone)
        })
      })

      it('rejects invalid phone numbers', () => {
        const invalidPhones = [
          '123',
          'abc-def-ghij',
          '1-800-FLOWERS',
          '123-45-6789',
          '+44 123 456 7890', // International format not supported
          '',
        ]

        invalidPhones.forEach(phone => {
          expect(() => phoneSchema.parse(phone)).toThrow('Please enter a valid phone number')
        })
      })
    })
  })

  describe('Marketing-Specific Schemas', () => {
    describe('campaignNameSchema', () => {
      it('accepts valid campaign names', () => {
        const validNames = [
          'Summer Campaign 2024',
          'Black Friday Sale',
          'New Product Launch',
          'Q4 Marketing Blitz',
          'Holiday Special Promotion',
        ]

        validNames.forEach(name => {
          expect(() => campaignNameSchema.parse(name)).not.toThrow()
          expect(campaignNameSchema.parse(name)).toBe(name)
        })
      })

      it('rejects empty campaign names', () => {
        expect(() => campaignNameSchema.parse('')).toThrow('Campaign name is required')
      })

      it('rejects campaign names that are too long', () => {
        const longName = 'a'.repeat(101)
        expect(() => campaignNameSchema.parse(longName)).toThrow('Campaign name must be less than 100 characters')
      })
    })

    describe('contentTitleSchema', () => {
      it('accepts valid content titles', () => {
        const validTitles = [
          'How to Boost Your Marketing ROI',
          '10 Tips for Social Media Success',
          'The Ultimate Guide to Email Marketing',
          'Why Content Marketing Matters',
        ]

        validTitles.forEach(title => {
          expect(() => contentTitleSchema.parse(title)).not.toThrow()
          expect(contentTitleSchema.parse(title)).toBe(title)
        })
      })

      it('rejects empty titles', () => {
        expect(() => contentTitleSchema.parse('')).toThrow('Title is required')
      })

      it('rejects titles that are too long', () => {
        const longTitle = 'a'.repeat(201)
        expect(() => contentTitleSchema.parse(longTitle)).toThrow('Title must be less than 200 characters')
      })
    })

    describe('contentDescriptionSchema', () => {
      it('accepts valid content descriptions', () => {
        const validDescriptions = [
          'This is a comprehensive guide that will help you understand the fundamentals of marketing.',
          'A detailed analysis of modern marketing strategies and their effectiveness in today\'s digital landscape.',
          'Learn how to create compelling content that engages your audience and drives conversions.',
        ]

        validDescriptions.forEach(description => {
          expect(() => contentDescriptionSchema.parse(description)).not.toThrow()
          expect(contentDescriptionSchema.parse(description)).toBe(description)
        })
      })

      it('rejects descriptions that are too short', () => {
        const shortDescription = 'short'
        expect(() => contentDescriptionSchema.parse(shortDescription)).toThrow('Description must be at least 10 characters')
      })

      it('rejects descriptions that are too long', () => {
        const longDescription = 'a'.repeat(1001)
        expect(() => contentDescriptionSchema.parse(longDescription)).toThrow('Description must be less than 1000 characters')
      })
    })

    describe('tagSchema', () => {
      it('accepts valid tags', () => {
        const validTags = [
          'marketing',
          'social-media',
          'email_campaign',
          'content-marketing',
          'seo',
          'analytics',
          'conversion-optimization',
        ]

        validTags.forEach(tag => {
          expect(() => tagSchema.parse(tag)).not.toThrow()
          expect(tagSchema.parse(tag)).toBe(tag)
        })
      })

      it('rejects tags with invalid characters', () => {
        const invalidTags = [
          'marketing!',
          'social media', // spaces not allowed
          'email@campaign',
          'content/marketing',
          'tag with spaces',
          'special@chars',
        ]

        invalidTags.forEach(tag => {
          expect(() => tagSchema.parse(tag)).toThrow(/Tags can only contain letters, numbers, hyphens, and underscores/)
        })
      })

      it('rejects tags that are too long', () => {
        const longTag = 'a'.repeat(51)
        expect(() => tagSchema.parse(longTag)).toThrow('Tag must be less than 50 characters')
      })
    })
  })

  describe('Form Schemas', () => {
    describe('contentGenerationSchema', () => {
      it('accepts valid content generation data', () => {
        const validData: ContentGenerationFormData = {
          title: 'How to Create Engaging Content',
          description: 'This comprehensive guide covers all the essential strategies for creating content that resonates with your audience.',
          contentType: 'blog-post',
          targetAudience: 'marketers',
          tone: 'professional',
          keywords: 'content, marketing, engagement',
          additionalInstructions: 'Make it beginner-friendly',
        }

        expect(() => contentGenerationSchema.parse(validData)).not.toThrow()
        const result = contentGenerationSchema.parse(validData)
        expect(result.title).toBe(validData.title)
        expect(result.contentType).toBe(validData.contentType)
      })

      it('rejects invalid content types', () => {
        const invalidData = {
          title: 'Valid Title',
          description: 'This is a valid description that meets the minimum length requirement.',
          contentType: 'invalid-type',
        }

        expect(() => contentGenerationSchema.parse(invalidData)).toThrow('Please select a content type')
      })

      it('validates all required fields', () => {
        const incompleteData = {
          // Missing required fields
        }

        expect(() => contentGenerationSchema.parse(incompleteData)).toThrow()
      })
    })

    describe('campaignSchema', () => {
      it('accepts valid campaign data', () => {
        const validData: CampaignFormData = {
          name: 'Summer Sale 2024',
          description: 'Comprehensive summer marketing campaign',
          startDate: new Date('2024-06-01'),
          endDate: new Date('2024-08-31'),
          budget: 10000,
          status: 'draft',
          targetAudience: ['young-adults', 'professionals'],
          goals: ['increase-sales', 'brand-awareness'],
        }

        expect(() => campaignSchema.parse(validData)).not.toThrow()
        const result = campaignSchema.parse(validData)
        expect(result.name).toBe(validData.name)
        expect(result.budget).toBe(validData.budget)
      })

      it('rejects negative budget values', () => {
        const invalidData = {
          name: 'Test Campaign',
          description: 'Test description',
          startDate: new Date('2024-06-01'),
          endDate: new Date('2024-08-31'),
          budget: -1000,
          status: 'draft',
        }

        expect(() => campaignSchema.parse(invalidData)).toThrow(/Budget must be a positive number/)
      })
    })

    describe('userProfileSchema', () => {
      it('accepts valid user profile data', () => {
        const validData: UserProfileFormData = {
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          company: 'Marketing Inc',
          jobTitle: 'Marketing Manager',
          phone: '(555) 123-4567',
          timezone: 'America/New_York',
        }

        expect(() => userProfileSchema.parse(validData)).not.toThrow()
        const result = userProfileSchema.parse(validData)
        expect(result.email).toBe(validData.email)
        expect(result.firstName).toBe(validData.firstName)
      })

      it('validates email format in user profile', () => {
        const invalidData = {
          firstName: 'John',
          lastName: 'Doe',
          email: 'invalid-email',
          company: 'Marketing Inc',
        }

        expect(() => userProfileSchema.parse(invalidData)).toThrow('Please enter a valid email address')
      })
    })

    describe('loginSchema', () => {
      it('accepts valid login credentials', () => {
        const validData: LoginFormData = {
          email: 'user@example.com',
          password: 'SecurePassword123!',
          rememberMe: true,
        }

        expect(() => loginSchema.parse(validData)).not.toThrow()
        const result = loginSchema.parse(validData)
        expect(result.email).toBe(validData.email)
        expect(result.rememberMe).toBe(true)
      })

      it('validates email and password requirements', () => {
        const invalidData = {
          email: 'invalid-email',
          password: 'weak',
        }

        expect(() => loginSchema.parse(invalidData)).toThrow()
      })
    })

    describe('registerSchema', () => {
      it('accepts valid registration data', () => {
        const validData: RegisterFormData = {
          email: 'newuser@example.com',
          password: 'StrongPass1!',
          confirmPassword: 'StrongPass1!',
          firstName: 'Jane',
          lastName: 'Smith',
          acceptTerms: true,
        }

        expect(() => registerSchema.parse(validData)).not.toThrow()
        const result = registerSchema.parse(validData)
        expect(result.email).toBe(validData.email)
        expect(result.acceptTerms).toBe(true)
      })

      it('rejects when passwords do not match', () => {
        const invalidData = {
          email: 'user@example.com',
          password: 'Password1!',
          confirmPassword: 'Different1!',
          firstName: 'John',
          lastName: 'Doe',
          acceptTerms: true,
        }

        expect(() => registerSchema.parse(invalidData)).toThrow('Passwords don\'t match')
      })

      it('requires agreement to terms', () => {
        const invalidData = {
          email: 'user@example.com',
          password: 'Password1!',
          confirmPassword: 'Password1!',
          firstName: 'John',
          lastName: 'Doe',
          acceptTerms: false,
        }

        expect(() => registerSchema.parse(invalidData)).toThrow('You must accept the terms')
      })
    })

    describe('templateSchema', () => {
      it('accepts valid template data', () => {
        const validData: TemplateFormData = {
          name: 'Email Newsletter Template',
          description: 'Professional newsletter template for marketing campaigns',
          category: 'email',
          content: '<h1>Welcome to our newsletter!</h1><p>{{content}}</p>',
          variables: ['content', 'name', 'company'],
          isPublic: true,
        }

        expect(() => templateSchema.parse(validData)).not.toThrow()
        const result = templateSchema.parse(validData)
        expect(result.name).toBe(validData.name)
        expect(result.isPublic).toBe(true)
      })

      it('validates template categories', () => {
        const invalidData = {
          name: 'Test Template',
          description: 'Test description',
          category: 'invalid-category',
          content: 'Test content',
          isPublic: false,
        }

        expect(() => templateSchema.parse(invalidData)).toThrow()
      })
    })
  })

  describe('Edge Cases and Complex Validation', () => {
    it('handles empty strings vs undefined for optional fields', () => {
      const dataWithEmptyStrings = {
        title: 'Valid Title',
        description: 'This is a valid description that meets the minimum length requirement.',
        contentType: 'blog-post' as const,
        targetAudience: 'general', // Required field, can't be empty
        tone: 'professional' as const,
        keywords: '', // Empty string for optional field
        additionalInstructions: '', // Empty string for optional field
      }

      // Should not throw - empty strings are acceptable for optional fields
      expect(() => contentGenerationSchema.parse(dataWithEmptyStrings)).not.toThrow()
    })

    it('validates array fields properly', () => {
      const validDataWithArrays = {
        name: 'Test Campaign',
        description: 'Valid description that meets minimum length requirements',
        startDate: new Date(),
        endDate: new Date(Date.now() + 86400000), // Tomorrow
        budget: 1000,
        status: 'draft' as const,
        tags: ['marketing', 'social-media'], // This is the array field in campaign schema
      }

      expect(() => campaignSchema.parse(validDataWithArrays)).not.toThrow()
    })

    it('handles international characters in text fields', () => {
      const internationalData = {
        title: 'Guía de Marketing para España',
        description: 'Esta es una descripción completa que incluye caracteres especiales como ñ, á, é, í, ó, ú.',
        contentType: 'blog-post' as const,
        targetAudience: 'spanish-speakers',
        tone: 'friendly' as const,
        keywords: 'marketing, españa', // String, not array
      }

      expect(() => contentGenerationSchema.parse(internationalData)).not.toThrow()
    })

    it('validates date ranges in campaigns', () => {
      const invalidDateRange = {
        name: 'Invalid Campaign',
        description: 'Campaign with invalid date range that should fail validation',
        startDate: new Date('2024-08-31'),
        endDate: new Date('2024-06-01'), // End before start
        budget: 1000,
        status: 'draft' as const,
      }

      // The schema DOES validate date ranges with a refine function
      expect(() => campaignSchema.parse(invalidDateRange)).toThrow('End date must be after start date')
    })

    it('handles very long valid content within limits', () => {
      const longButValidContent = {
        title: 'A'.repeat(199), // Just under the 200 limit
        description: 'B'.repeat(999), // Just under the 1000 limit
        contentType: 'blog-post' as const,
        targetAudience: 'general',
        tone: 'professional' as const,
        keywords: 'long-content, testing', // String, not array
      }

      expect(() => contentGenerationSchema.parse(longButValidContent)).not.toThrow()
    })
  })
})