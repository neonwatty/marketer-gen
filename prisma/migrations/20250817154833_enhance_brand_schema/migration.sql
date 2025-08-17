/*
  Warnings:

  - You are about to drop the column `assets` on the `brands` table. All the data in the column will be lost.
  - You are about to drop the column `guidelines` on the `brands` table. All the data in the column will be lost.
  - You are about to drop the column `messaging` on the `brands` table. All the data in the column will be lost.

*/
-- CreateTable
CREATE TABLE "brand_assets" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "brandId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "type" TEXT NOT NULL,
    "category" TEXT,
    "fileUrl" TEXT NOT NULL,
    "fileName" TEXT NOT NULL,
    "fileSize" INTEGER,
    "mimeType" TEXT,
    "metadata" JSONB,
    "tags" JSONB,
    "version" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "downloadCount" INTEGER NOT NULL DEFAULT 0,
    "lastUsed" DATETIME,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    "deletedAt" DATETIME,
    "createdBy" TEXT,
    "updatedBy" TEXT,
    CONSTRAINT "brand_assets_brandId_fkey" FOREIGN KEY ("brandId") REFERENCES "brands" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "color_palettes" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "brandId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "colors" JSONB NOT NULL,
    "isPrimary" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    "deletedAt" DATETIME,
    "createdBy" TEXT,
    "updatedBy" TEXT,
    CONSTRAINT "color_palettes_brandId_fkey" FOREIGN KEY ("brandId") REFERENCES "brands" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "typography" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "brandId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "fontFamily" TEXT NOT NULL,
    "fontWeight" TEXT,
    "fontSize" TEXT,
    "lineHeight" TEXT,
    "letterSpacing" TEXT,
    "usage" TEXT,
    "isPrimary" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "fontFileUrl" TEXT,
    "fallbackFonts" JSONB,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    "deletedAt" DATETIME,
    "createdBy" TEXT,
    "updatedBy" TEXT,
    CONSTRAINT "typography_brandId_fkey" FOREIGN KEY ("brandId") REFERENCES "brands" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_brands" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "industry" TEXT,
    "website" TEXT,
    "tagline" TEXT,
    "mission" TEXT,
    "vision" TEXT,
    "values" JSONB,
    "personality" JSONB,
    "voiceDescription" TEXT,
    "toneAttributes" JSONB,
    "communicationStyle" TEXT,
    "messagingFramework" JSONB,
    "brandPillars" JSONB,
    "targetAudience" JSONB,
    "competitivePosition" TEXT,
    "brandPromise" TEXT,
    "complianceRules" JSONB,
    "usageGuidelines" JSONB,
    "restrictedTerms" JSONB,
    "userId" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    "deletedAt" DATETIME,
    "createdBy" TEXT,
    "updatedBy" TEXT,
    CONSTRAINT "brands_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
INSERT INTO "new_brands" ("createdAt", "createdBy", "deletedAt", "id", "name", "updatedAt", "updatedBy", "userId") SELECT "createdAt", "createdBy", "deletedAt", "id", "name", "updatedAt", "updatedBy", "userId" FROM "brands";
DROP TABLE "brands";
ALTER TABLE "new_brands" RENAME TO "brands";
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;

-- CreateIndex
CREATE INDEX "brand_assets_brandId_idx" ON "brand_assets"("brandId");

-- CreateIndex
CREATE INDEX "brand_assets_type_idx" ON "brand_assets"("type");

-- CreateIndex
CREATE INDEX "brand_assets_category_idx" ON "brand_assets"("category");

-- CreateIndex
CREATE INDEX "color_palettes_brandId_idx" ON "color_palettes"("brandId");

-- CreateIndex
CREATE INDEX "typography_brandId_idx" ON "typography"("brandId");
