export { default as CommentSystem } from './comment-system'
export { default as CommentThread } from './comment-thread'
export { default as CommentMentions } from './comment-mentions'
export { default as CommentModeration } from './comment-moderation'

export type { CommentSystemProps } from './comment-system'
export type { CommentThreadProps } from './comment-thread'
export type { CommentMentionsProps, MentionUser } from './comment-mentions'
export type { CommentModerationProps } from './comment-moderation'

// Utility exports
export { extractMentions, renderMentions } from './comment-mentions'