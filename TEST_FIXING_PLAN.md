# Test Suite Fixing Plan

## Current Status (Updated)
- **Total Tests**: 757
- **Errors**: 249 (down from 408) ✅
- **Failures**: 71 (up from 46) 
- **Assertions**: 2,726 (up from 1,292) ✅
- **Coverage**: 2.64% (up from 1.78%) ✅

## Error Categories Analysis

### 1. Route Helper Errors (High Priority)
**Count**: ~15-20 errors
**Pattern**: `undefined local variable or method 'xyz_url'`

**Examples**:
- `overview_api_v1_analytics_index_url`
- `trends_api_v1_analytics_index_url`
- `journey_analytics_api_v1_analytics_index_url`

**Root Cause**: Incorrect route helper names in controller tests
**Solution**: Fix route helper names to match actual routes defined

**Files to Fix**:
- `test/controllers/api/v1/analytics_controller_test.rb`
- Other API controller tests

---

### 2. Missing Model Attributes (High Priority) 
**Count**: ~10-15 errors
**Pattern**: `undefined method 'attribute_name=' for model instance`

**Examples**:
- `configuration=` for AbTestVariant
- `minimum_sample_size=` for AbTest

**Root Cause**: Tests trying to set attributes that don't exist in models
**Solution**: Add missing attributes to models or update tests

**Files to Fix**:
- `app/models/ab_test.rb`
- `app/models/ab_test_variant.rb`
- Related test files

---

### 3. Authentication/Authorization Errors (Medium Priority)
**Count**: ~20-25 errors  
**Pattern**: Tests failing due to authentication requirements

**Examples**:
- Admin panel access tests
- Controller tests requiring authentication

**Root Cause**: Tests not properly signing in users before making requests
**Solution**: Use `sign_in_as` helper consistently

**Files to Fix**:
- Admin controller tests
- Integration tests
- Controller tests requiring auth

---

### 4. Missing Test Helper Methods (Medium Priority)
**Count**: ~5-10 errors
**Pattern**: `undefined method 'helper_method_name'`

**Examples**:
- `assert_enqueued_emails`

**Root Cause**: Tests using helper methods that don't exist or aren't imported
**Solution**: Add missing helper methods or include proper modules

**Files to Fix**:
- `test/test_helper.rb`
- Service tests using email assertions

---

### 5. Activity Tracking Validation Errors (Medium Priority)
**Count**: ~5-8 errors
**Pattern**: `Validation failed: Action can't be blank, Controller can't be blank`

**Root Cause**: Activity model validations not being met in tests
**Solution**: Provide required fields when creating activities

**Files to Fix**:
- `test/models/activity_test.rb`
- Tests creating Activity records

---

### 6. Security/Headers Test Errors (Low Priority)
**Count**: ~5-10 errors
**Pattern**: Security header and CSP tests failing

**Root Cause**: Security configurations not properly set up in test environment
**Solution**: Configure security headers for test environment

**Files to Fix**:
- `test/controllers/security_headers_test.rb`
- Test environment configuration

---

## Implementation Plan

### Phase 1: Route Helper Fixes (Week 1) - COMPLETED ✅
1. ✅ **Audit all controller tests** for incorrect route helpers
2. ✅ **Fix API analytics controller** route helpers (13 tests passing)
3. ✅ **Update journey controller** route helpers  
4. ✅ **Fix brand management** route helpers
5. ✅ **Test each controller individually** after fixes

**Expected Impact**: Reduce ~20 errors
**Actual Impact**: Reduced 159 errors total (including other fixes)

### Phase 2: Model Attribute Fixes (Week 1-2) - COMPLETED ✅
1. ✅ **Review AB test models** and add missing attributes
   - Added `assign_visitor`, `performance_report`, `generate_insights`, `complete_test!`
   - Added `minimum_sample_size` accessor
   - Added `meets_minimum_sample_size?` method
2. ✅ **Check journey models** for missing attributes
3. ✅ **Update factory definitions** if needed
   - Fixed AbTestVariant factory to use metadata instead of configuration
4. ✅ **Add proper validations** to models
5. ✅ **Update tests** to use correct attributes

**Expected Impact**: Reduce ~15 errors
**Actual Impact**: Fixed ~10 AB test related errors

### Phase 3: Authentication Fixes (Week 2) - PARTIALLY COMPLETED
1. ✅ **Audit all controller tests** for missing authentication
2. ✅ **Add `sign_in` helper method** for controller tests
3. ✅ **Fix cookie handling** for integration tests
4. ⚠️ **Update integration tests** with authentication (some remaining)
5. **Create admin user factories** if needed

**Expected Impact**: Reduce ~25 errors
**Actual Impact**: Fixed ~9 sign_in errors, cookie handling improved

### Phase 4: Test Helper & Validation Fixes (Week 2-3) - PARTIALLY COMPLETED
1. ✅ **Add VCR stub** for tests expecting it
2. ✅ **Add asset precompilation fixes** (65+ errors fixed)
   - Added file_upload_controller.js
   - Added messaging_framework_controller.js  
   - Added sortable_controller.js
3. **Fix activity validation errors**
4. **Update factory definitions**
5. **Fix email/job testing helpers**

**Expected Impact**: Reduce ~15 errors
**Actual Impact**: Fixed 65+ asset precompilation errors

### Phase 5: Security & Environment Fixes (Week 3)
1. **Configure security headers for tests**
2. **Fix CSP and HSTS tests** 
3. **Update test environment config**
4. **Fix admin access tests**
5. **Clean up skipped tests**

**Expected Impact**: Reduce ~10 errors

### Phase 6: Coverage & Cleanup (Week 3-4)
1. **Review remaining failures**
2. **Fix edge cases**
3. **Improve test coverage**
4. **Optimize test performance**
5. **Document test patterns**

**Expected Impact**: Final cleanup, increase coverage

---

## Success Metrics

### Targets by Phase:
- **Phase 1**: Errors: 280 (-20), Coverage: 2.5%
- **Phase 2**: Errors: 265 (-15), Coverage: 3.0%  
- **Phase 3**: Errors: 240 (-25), Coverage: 4.0%
- **Phase 4**: Errors: 225 (-15), Coverage: 5.0%
- **Phase 5**: Errors: 215 (-10), Coverage: 6.0%
- **Phase 6**: Errors: <200, Coverage: >8.0%

### Final Goals:
- **Errors**: <150 (from 300)
- **Failures**: <30 (from 46)
- **Coverage**: >10%
- **All critical paths tested**

---

## Quality Gates

Before moving to next phase:
1. ✅ **Run full test suite** and verify error reduction
2. ✅ **Check no new errors introduced**
3. ✅ **Coverage improvement verified**
4. ✅ **Commit and push changes**
5. ✅ **Update this document** with progress

---

## File Priority Matrix

### High Priority (Fix First):
- `test/controllers/api/v1/analytics_controller_test.rb`
- `app/models/ab_test.rb` and `app/models/ab_test_variant.rb`
- `test/controllers/brands_controller_test.rb` (partially done)
- `test/integration/admin_workflow_test.rb`

### Medium Priority:
- `test/models/activity_test.rb`
- `test/controllers/security_headers_test.rb`
- Service test files with missing helpers
- Authentication integration tests

### Low Priority:
- Performance tests
- Edge case tests
- Cleanup and optimization

---

## Notes
- This plan will be updated after each phase
- Error counts are estimates based on current analysis
- Focus on systematic fixes rather than one-off solutions
- Maintain test quality while increasing coverage

## Progress Summary
- **Initial State**: 408 errors, 1.78% coverage
- **Current State**: 249 errors, 2.64% coverage
- **Total Reduction**: 159 errors fixed (39% improvement)
- **Major Wins**: 
  - All API analytics controller tests passing
  - 65+ asset precompilation errors fixed
  - Authentication flow improved
  - AB test models fully functional