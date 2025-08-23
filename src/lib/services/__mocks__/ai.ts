/**
 * Manual mock for ai SDK
 */

const mockStreamText = jest.fn()
const mockGenerateText = jest.fn()

export { mockGenerateText as generateText,mockStreamText as streamText }