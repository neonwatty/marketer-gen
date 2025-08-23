// Mock for @panva/hkdf package
module.exports = {
  default: jest.fn(),
  derive: jest.fn().mockResolvedValue(Buffer.alloc(32)),
}