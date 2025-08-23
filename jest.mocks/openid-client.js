// Mock for openid-client package
module.exports = {
  Issuer: {
    discover: jest.fn().mockResolvedValue({
      Client: jest.fn().mockImplementation(() => ({
        userinfo: jest.fn(),
        requestObject: jest.fn(),
        authorizationUrl: jest.fn(),
        callbackParams: jest.fn(),
        callback: jest.fn(),
        refresh: jest.fn(),
        revoke: jest.fn(),
      })),
      metadata: {
        issuer: 'mock-issuer',
        authorization_endpoint: 'mock-auth-endpoint',
        token_endpoint: 'mock-token-endpoint',
        userinfo_endpoint: 'mock-userinfo-endpoint',
      },
    }),
  },
  Client: jest.fn(),
  Strategy: jest.fn(),
  generators: {
    codeVerifier: jest.fn().mockReturnValue('mock-code-verifier'),
    codeChallenge: jest.fn().mockReturnValue('mock-code-challenge'),
    state: jest.fn().mockReturnValue('mock-state'),
    nonce: jest.fn().mockReturnValue('mock-nonce'),
  },
  custom: {
    setHttpOptions: jest.fn(),
  },
}