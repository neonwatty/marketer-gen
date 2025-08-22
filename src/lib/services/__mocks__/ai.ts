/**
 * Manual mock for ai SDK
 */

const mockStreamText = jest.fn()
const mockGenerateText = jest.fn()

export { mockStreamText as streamText, mockGenerateText as generateText }