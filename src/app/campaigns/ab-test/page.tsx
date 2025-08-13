import { ABTestSetup } from "@/components/campaigns/ab-test-setup"

export default function ABTestPage() {
  const handleSave = (config: any) => {
    console.log("A/B Test Configuration:", config)
    // Here you would save the configuration and start the test
  }

  const handleCancel = () => {
    console.log("A/B Test setup cancelled")
    // Navigate back or close modal
  }

  return (
    <div className="space-y-6">
      <ABTestSetup onSave={handleSave} onCancel={handleCancel} />
    </div>
  )
}