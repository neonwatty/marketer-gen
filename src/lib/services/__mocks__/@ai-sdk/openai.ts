/**
 * Manual mock for @ai-sdk/openai
 */

const mockOpenai = jest.fn((model: string) => model)

export { mockOpenai as openai }