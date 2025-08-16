import { Card, CardContent, CardHeader } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'

export function CampaignCardSkeleton() {
  return (
    <Card>
      <CardHeader>
        <div className="flex items-start justify-between">
          <div className="flex-1 space-y-2">
            <Skeleton className="h-5 w-3/4" />
            <Skeleton className="h-4 w-full" />
            <Skeleton className="h-4 w-2/3" />
          </div>
          <div className="ml-4 flex items-center gap-2">
            <Skeleton className="h-6 w-16" />
            <Skeleton className="h-8 w-8" />
          </div>
        </div>
      </CardHeader>

      <CardContent className="space-y-4">
        {/* Key Metrics Skeleton */}
        <div className="grid grid-cols-3 gap-4">
          <div className="text-center space-y-2">
            <Skeleton className="h-3 w-16 mx-auto" />
            <Skeleton className="h-6 w-12 mx-auto" />
          </div>
          <div className="text-center space-y-2">
            <Skeleton className="h-3 w-16 mx-auto" />
            <Skeleton className="h-6 w-12 mx-auto" />
          </div>
          <div className="text-center space-y-2">
            <Skeleton className="h-3 w-16 mx-auto" />
            <Skeleton className="h-6 w-8 mx-auto" />
          </div>
        </div>

        {/* Progress Skeleton */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <Skeleton className="h-4 w-24" />
            <Skeleton className="h-4 w-10" />
          </div>
          <Skeleton className="h-2 w-full" />
        </div>

        {/* Additional Metrics Skeleton */}
        <div className="border-t pt-3">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1">
              <Skeleton className="h-3 w-16" />
              <Skeleton className="h-4 w-12" />
            </div>
            <div className="space-y-1">
              <Skeleton className="h-3 w-20" />
              <Skeleton className="h-4 w-14" />
            </div>
          </div>
        </div>

        {/* Last Updated Skeleton */}
        <div className="border-t pt-3">
          <Skeleton className="h-3 w-32" />
        </div>
      </CardContent>
    </Card>
  )
}

export function CampaignCardSkeletonGrid({ count = 6 }: { count?: number }) {
  return (
    <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
      {Array.from({ length: count }).map((_, i) => (
        <CampaignCardSkeleton key={i} />
      ))}
    </div>
  )
}