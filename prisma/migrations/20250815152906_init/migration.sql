-- AlterTable
ALTER TABLE "brands" ADD COLUMN "createdBy" TEXT;
ALTER TABLE "brands" ADD COLUMN "deletedAt" DATETIME;
ALTER TABLE "brands" ADD COLUMN "updatedBy" TEXT;

-- AlterTable
ALTER TABLE "campaigns" ADD COLUMN "createdBy" TEXT;
ALTER TABLE "campaigns" ADD COLUMN "deletedAt" DATETIME;
ALTER TABLE "campaigns" ADD COLUMN "updatedBy" TEXT;

-- AlterTable
ALTER TABLE "users" ADD COLUMN "deletedAt" DATETIME;

-- CreateTable
CREATE TABLE "journeys" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "campaignId" TEXT NOT NULL,
    "stages" JSONB NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'DRAFT',
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    "deletedAt" DATETIME,
    "createdBy" TEXT,
    "updatedBy" TEXT,
    CONSTRAINT "journeys_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "campaigns" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "content" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "journeyId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'DRAFT',
    "variants" JSONB,
    "metadata" JSONB,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    "deletedAt" DATETIME,
    "createdBy" TEXT,
    "updatedBy" TEXT,
    CONSTRAINT "content_journeyId_fkey" FOREIGN KEY ("journeyId") REFERENCES "journeys" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "content_templates" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "type" TEXT NOT NULL,
    "template" TEXT NOT NULL,
    "category" TEXT,
    "variables" JSONB,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    "deletedAt" DATETIME,
    "createdBy" TEXT,
    "updatedBy" TEXT
);

-- CreateTable
CREATE TABLE "analytics" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "campaignId" TEXT NOT NULL,
    "contentId" TEXT,
    "journeyId" TEXT,
    "eventType" TEXT NOT NULL,
    "metrics" JSONB NOT NULL,
    "timestamp" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "source" TEXT,
    "sessionId" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    "deletedAt" DATETIME,
    "createdBy" TEXT,
    "updatedBy" TEXT,
    CONSTRAINT "analytics_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "campaigns" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "analytics_contentId_fkey" FOREIGN KEY ("contentId") REFERENCES "content" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "analytics_journeyId_fkey" FOREIGN KEY ("journeyId") REFERENCES "journeys" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

-- CreateIndex
CREATE INDEX "analytics_campaignId_idx" ON "analytics"("campaignId");

-- CreateIndex
CREATE INDEX "analytics_contentId_idx" ON "analytics"("contentId");

-- CreateIndex
CREATE INDEX "analytics_journeyId_idx" ON "analytics"("journeyId");

-- CreateIndex
CREATE INDEX "analytics_timestamp_idx" ON "analytics"("timestamp");

-- CreateIndex
CREATE INDEX "analytics_eventType_idx" ON "analytics"("eventType");
