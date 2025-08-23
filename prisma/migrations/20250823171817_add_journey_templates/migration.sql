-- CreateTable
CREATE TABLE "journey_templates" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "industry" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "stages" JSONB NOT NULL,
    "metadata" JSONB,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "isPublic" BOOLEAN NOT NULL DEFAULT true,
    "customizationConfig" JSONB,
    "defaultSettings" JSONB,
    "usageCount" INTEGER NOT NULL DEFAULT 0,
    "rating" REAL,
    "ratingCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    "deletedAt" DATETIME,
    "createdBy" TEXT,
    "updatedBy" TEXT
);

-- CreateIndex
CREATE INDEX "journey_templates_industry_idx" ON "journey_templates"("industry");

-- CreateIndex
CREATE INDEX "journey_templates_category_idx" ON "journey_templates"("category");

-- CreateIndex
CREATE INDEX "journey_templates_isActive_idx" ON "journey_templates"("isActive");

-- CreateIndex
CREATE INDEX "journey_templates_isPublic_idx" ON "journey_templates"("isPublic");
