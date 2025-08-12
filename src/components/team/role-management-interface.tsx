'use client'

import React, { useState, useEffect } from 'react'
import { 
  User, 
  UserRole, 
  TeamRole, 
  TeamMember,
  TeamPermissions,
  UserPermissions 
} from '@/types'
import { 
  ROLE_HIERARCHY,
  TEAM_ROLE_PERMISSIONS,
  RoleManager,
  CombinedPermissionChecker,
  validateComponentAccess
} from '@/lib/permissions'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger } from '@/components/ui/alert'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Users, Shield, Settings, UserPlus, UserMinus, Crown, Star } from 'lucide-react'

export interface RoleManagementInterfaceProps {
  currentUser: User
  teamMembers: TeamMember[]
  onUpdateMemberRole: (memberId: string, newRole: UserRole, newTeamRole: TeamRole) => Promise<void>
  onRemoveMember: (memberId: string) => Promise<void>
  onInviteMember: (email: string, role: UserRole, teamRole: TeamRole) => Promise<void>
  onUpdatePermissions: (memberId: string, permissions: Partial<UserPermissions & TeamPermissions>) => Promise<void>
  isLoading?: boolean
}

interface RoleChangeModalProps {
  member: TeamMember
  currentUserRole: UserRole
  currentUserTeamRole: TeamRole
  onConfirm: (newRole: UserRole, newTeamRole: TeamRole) => void
  onCancel: () => void
  open: boolean
}

const RoleChangeModal: React.FC<RoleChangeModalProps> = ({
  member,
  currentUserRole,
  currentUserTeamRole,
  onConfirm,
  onCancel,
  open
}) => {
  const [selectedUserRole, setSelectedUserRole] = useState<UserRole>(member.user.role)
  const [selectedTeamRole, setSelectedTeamRole] = useState<TeamRole>(member.role)

  const assignableUserRoles = RoleManager.getAssignableRoles(currentUserRole)
  const assignableTeamRoles = RoleManager.getAssignableTeamRoles(currentUserTeamRole)

  const handleConfirm = () => {
    onConfirm(selectedUserRole, selectedTeamRole)
  }

  return (
    <Dialog open={open} onOpenChange={onCancel}>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>Update Role for {member.user.name}</DialogTitle>
          <DialogDescription>
            Change the user's role and team permissions. This will affect their access to features and content.
          </DialogDescription>
        </DialogHeader>
        
        <div className="grid gap-4 py-4">
          <div className="grid gap-2">
            <Label htmlFor="user-role">User Role</Label>
            <Select value={selectedUserRole} onValueChange={(value: UserRole) => setSelectedUserRole(value)}>
              <SelectTrigger>
                <SelectValue placeholder="Select user role" />
              </SelectTrigger>
              <SelectContent>
                {ROLE_HIERARCHY
                  .filter(({ role }) => assignableUserRoles.includes(role))
                  .map(({ role, label, description }) => (
                    <SelectItem key={role} value={role}>
                      <div className="flex flex-col">
                        <span>{label}</span>
                        <span className="text-xs text-muted-foreground">{description}</span>
                      </div>
                    </SelectItem>
                  ))}
              </SelectContent>
            </Select>
          </div>

          <div className="grid gap-2">
            <Label htmlFor="team-role">Team Role</Label>
            <Select value={selectedTeamRole} onValueChange={(value: TeamRole) => setSelectedTeamRole(value)}>
              <SelectTrigger>
                <SelectValue placeholder="Select team role" />
              </SelectTrigger>
              <SelectContent>
                {assignableTeamRoles.map((role) => (
                  <SelectItem key={role} value={role}>
                    <div className="flex items-center gap-2">
                      {role === 'owner' && <Crown className="h-4 w-4" />}
                      {role === 'admin' && <Star className="h-4 w-4" />}
                      {role === 'member' && <Users className="h-4 w-4" />}
                      <span className="capitalize">{role}</span>
                    </div>
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>

        <div className="flex justify-end gap-2">
          <Button variant="outline" onClick={onCancel}>
            Cancel
          </Button>
          <Button onClick={handleConfirm}>
            Update Role
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  )
}

interface InviteMemberModalProps {
  currentUserRole: UserRole
  currentUserTeamRole: TeamRole
  onInvite: (email: string, role: UserRole, teamRole: TeamRole) => void
  onCancel: () => void
  open: boolean
}

const InviteMemberModal: React.FC<InviteMemberModalProps> = ({
  currentUserRole,
  currentUserTeamRole,
  onInvite,
  onCancel,
  open
}) => {
  const [email, setEmail] = useState('')
  const [selectedUserRole, setSelectedUserRole] = useState<UserRole>('creator')
  const [selectedTeamRole, setSelectedTeamRole] = useState<TeamRole>('member')

  const assignableUserRoles = RoleManager.getAssignableRoles(currentUserRole)
  const assignableTeamRoles = RoleManager.getAssignableTeamRoles(currentUserTeamRole)

  const handleInvite = () => {
    if (email.trim()) {
      onInvite(email.trim(), selectedUserRole, selectedTeamRole)
      setEmail('')
      setSelectedUserRole('creator')
      setSelectedTeamRole('member')
    }
  }

  return (
    <Dialog open={open} onOpenChange={onCancel}>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>Invite Team Member</DialogTitle>
          <DialogDescription>
            Send an invitation to join your team with the specified roles and permissions.
          </DialogDescription>
        </DialogHeader>
        
        <div className="grid gap-4 py-4">
          <div className="grid gap-2">
            <Label htmlFor="email">Email Address</Label>
            <Input
              id="email"
              type="email"
              placeholder="Enter email address"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>

          <div className="grid gap-2">
            <Label htmlFor="user-role">User Role</Label>
            <Select value={selectedUserRole} onValueChange={(value: UserRole) => setSelectedUserRole(value)}>
              <SelectTrigger>
                <SelectValue placeholder="Select user role" />
              </SelectTrigger>
              <SelectContent>
                {ROLE_HIERARCHY
                  .filter(({ role }) => assignableUserRoles.includes(role))
                  .map(({ role, label, description }) => (
                    <SelectItem key={role} value={role}>
                      <div className="flex flex-col">
                        <span>{label}</span>
                        <span className="text-xs text-muted-foreground">{description}</span>
                      </div>
                    </SelectItem>
                  ))}
              </SelectContent>
            </Select>
          </div>

          <div className="grid gap-2">
            <Label htmlFor="team-role">Team Role</Label>
            <Select value={selectedTeamRole} onValueChange={(value: TeamRole) => setSelectedTeamRole(value)}>
              <SelectTrigger>
                <SelectValue placeholder="Select team role" />
              </SelectTrigger>
              <SelectContent>
                {assignableTeamRoles.map((role) => (
                  <SelectItem key={role} value={role}>
                    <div className="flex items-center gap-2">
                      {role === 'owner' && <Crown className="h-4 w-4" />}
                      {role === 'admin' && <Star className="h-4 w-4" />}
                      {role === 'member' && <Users className="h-4 w-4" />}
                      <span className="capitalize">{role}</span>
                    </div>
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>

        <div className="flex justify-end gap-2">
          <Button variant="outline" onClick={onCancel}>
            Cancel
          </Button>
          <Button onClick={handleInvite} disabled={!email.trim()}>
            Send Invitation
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  )
}

export const RoleManagementInterface: React.FC<RoleManagementInterfaceProps> = ({
  currentUser,
  teamMembers,
  onUpdateMemberRole,
  onRemoveMember,
  onInviteMember,
  onUpdatePermissions,
  isLoading = false
}) => {
  const [selectedMember, setSelectedMember] = useState<TeamMember | null>(null)
  const [showRoleModal, setShowRoleModal] = useState(false)
  const [showInviteModal, setShowInviteModal] = useState(false)
  const [showRemoveDialog, setShowRemoveDialog] = useState(false)

  // Get current user's team role
  const currentUserMember = teamMembers.find(m => m.userId === currentUser.id)
  const currentUserTeamRole: TeamRole = currentUserMember?.role || 'member'

  // Check if current user can manage roles
  const canManageRoles = validateComponentAccess(
    currentUser.role,
    'canManageUsers',
    currentUserTeamRole,
    'canManageRoles'
  )

  const canInviteMembers = validateComponentAccess(
    currentUser.role,
    'canManageUsers',
    currentUserTeamRole,
    'canInviteMembers'
  )

  const handleRoleChange = async (newRole: UserRole, newTeamRole: TeamRole) => {
    if (selectedMember) {
      await onUpdateMemberRole(selectedMember.userId.toString(), newRole, newTeamRole)
      setShowRoleModal(false)
      setSelectedMember(null)
    }
  }

  const handleRemoveMember = async () => {
    if (selectedMember) {
      await onRemoveMember(selectedMember.userId.toString())
      setShowRemoveDialog(false)
      setSelectedMember(null)
    }
  }

  const handleInviteMember = async (email: string, role: UserRole, teamRole: TeamRole) => {
    await onInviteMember(email, role, teamRole)
    setShowInviteModal(false)
  }

  const getRoleBadgeVariant = (role: UserRole | TeamRole) => {
    switch (role) {
      case 'admin':
      case 'owner':
        return 'destructive'
      case 'approver':
      case 'publisher':
        return 'default'
      case 'reviewer':
        return 'secondary'
      default:
        return 'outline'
    }
  }

  if (!canManageRoles) {
    return (
      <Card>
        <CardContent className="pt-6">
          <div className="text-center text-muted-foreground">
            <Shield className="h-12 w-12 mx-auto mb-4 opacity-50" />
            <p>You don't have permission to manage team roles.</p>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Team Management</h2>
          <p className="text-muted-foreground">
            Manage team member roles and permissions
          </p>
        </div>
        
        {canInviteMembers && (
          <Button onClick={() => setShowInviteModal(true)}>
            <UserPlus className="h-4 w-4 mr-2" />
            Invite Member
          </Button>
        )}
      </div>

      <Tabs defaultValue="members" className="space-y-4">
        <TabsList>
          <TabsTrigger value="members">Members</TabsTrigger>
          <TabsTrigger value="permissions">Permissions</TabsTrigger>
        </TabsList>

        <TabsContent value="members" className="space-y-4">
          <div className="grid gap-4">
            {teamMembers.map((member) => {
              const canManageThisMember = RoleManager.canManageTeamRole(
                currentUserTeamRole,
                member.role
              ) && member.userId !== currentUser.id

              return (
                <Card key={member.userId}>
                  <CardContent className="pt-6">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-4">
                        <Avatar>
                          <AvatarImage src={member.user.avatar} />
                          <AvatarFallback>
                            {member.user.name.split(' ').map(n => n[0]).join('')}
                          </AvatarFallback>
                        </Avatar>
                        
                        <div>
                          <div className="flex items-center gap-2">
                            <h3 className="font-medium">{member.user.name}</h3>
                            {member.userId === currentUser.id && (
                              <Badge variant="outline">You</Badge>
                            )}
                          </div>
                          <p className="text-sm text-muted-foreground">{member.user.email}</p>
                          <div className="flex gap-2 mt-2">
                            <Badge variant={getRoleBadgeVariant(member.user.role)}>
                              {ROLE_HIERARCHY.find(r => r.role === member.user.role)?.label}
                            </Badge>
                            <Badge variant={getRoleBadgeVariant(member.role)}>
                              {member.role === 'owner' && <Crown className="h-3 w-3 mr-1" />}
                              {member.role === 'admin' && <Star className="h-3 w-3 mr-1" />}
                              Team {member.role}
                            </Badge>
                          </div>
                        </div>
                      </div>

                      {canManageThisMember && (
                        <div className="flex gap-2">
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => {
                              setSelectedMember(member)
                              setShowRoleModal(true)
                            }}
                          >
                            <Settings className="h-4 w-4 mr-2" />
                            Edit Role
                          </Button>
                          
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => {
                              setSelectedMember(member)
                              setShowRemoveDialog(true)
                            }}
                          >
                            <UserMinus className="h-4 w-4 mr-2" />
                            Remove
                          </Button>
                        </div>
                      )}
                    </div>
                  </CardContent>
                </Card>
              )
            })}
          </div>
        </TabsContent>

        <TabsContent value="permissions" className="space-y-4">
          <div className="grid gap-6 md:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle>Content Permissions</CardTitle>
                <CardDescription>
                  Permissions related to content creation and management
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                {ROLE_HIERARCHY.map(({ role, label, description }) => (
                  <div key={role} className="space-y-2">
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="font-medium">{label}</p>
                        <p className="text-sm text-muted-foreground">{description}</p>
                      </div>
                      <Badge variant={getRoleBadgeVariant(role)}>{label}</Badge>
                    </div>
                  </div>
                ))}
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Team Permissions</CardTitle>
                <CardDescription>
                  Permissions related to team management and collaboration
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                {Object.entries(TEAM_ROLE_PERMISSIONS).map(([role, permissions]) => (
                  <div key={role} className="space-y-2">
                    <div className="flex items-center gap-2">
                      {role === 'owner' && <Crown className="h-4 w-4" />}
                      {role === 'admin' && <Star className="h-4 w-4" />}
                      {role === 'member' && <Users className="h-4 w-4" />}
                      <p className="font-medium capitalize">{role}</p>
                    </div>
                    <div className="text-sm text-muted-foreground pl-6">
                      {Object.entries(permissions)
                        .filter(([_, allowed]) => allowed)
                        .map(([permission, _]) => (
                          <div key={permission} className="capitalize">
                            {permission.replace(/([A-Z])/g, ' $1').toLowerCase()}
                          </div>
                        ))}
                    </div>
                  </div>
                ))}
              </CardContent>
            </Card>
          </div>
        </TabsContent>
      </Tabs>

      {/* Role Change Modal */}
      {selectedMember && (
        <RoleChangeModal
          member={selectedMember}
          currentUserRole={currentUser.role}
          currentUserTeamRole={currentUserTeamRole}
          onConfirm={handleRoleChange}
          onCancel={() => {
            setShowRoleModal(false)
            setSelectedMember(null)
          }}
          open={showRoleModal}
        />
      )}

      {/* Invite Member Modal */}
      <InviteMemberModal
        currentUserRole={currentUser.role}
        currentUserTeamRole={currentUserTeamRole}
        onInvite={handleInviteMember}
        onCancel={() => setShowInviteModal(false)}
        open={showInviteModal}
      />

      {/* Remove Member Dialog */}
      {selectedMember && (
        <AlertDialog open={showRemoveDialog} onOpenChange={setShowRemoveDialog}>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>Remove Team Member</AlertDialogTitle>
              <AlertDialogDescription>
                Are you sure you want to remove {selectedMember.user.name} from the team? 
                This action cannot be undone and they will lose access to all team resources.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel onClick={() => {
                setShowRemoveDialog(false)
                setSelectedMember(null)
              }}>
                Cancel
              </AlertDialogCancel>
              <AlertDialogAction onClick={handleRemoveMember}>
                Remove Member
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      )}
    </div>
  )
}

export default RoleManagementInterface