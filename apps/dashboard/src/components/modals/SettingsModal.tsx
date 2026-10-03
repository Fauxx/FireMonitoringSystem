import React, { useState } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { ModalOverlay } from './ModalOverlay';
import { ProfileTab } from '../settings/ProfileTab';
import { UserManagementTab } from '../settings/UserManagementTab';
import { PendingApprovalsTab } from '../settings/PendingApprovalsTab';
import { User, Users, ClipboardCheck } from 'lucide-react';

interface SettingsModalProps {
  onClose: () => void;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({ onClose }) => {
  const { isAdmin } = useAuth();
  const [activeTab, setActiveTab] = useState<'profile' | 'users' | 'approvals'>('profile');
  const [pendingCount, setPendingCount] = useState(0);

  return (
    <ModalOverlay title="Settings" onClose={onClose} width="max-w-4xl">
      <div className="flex flex-col h-[600px] max-h-[80vh] text-slate-900">
        <div className="flex border-b border-surface-border bg-base-dark">
          <button
            onClick={() => setActiveTab('profile')}
            className={`flex items-center gap-2 px-6 py-3 text-sm font-medium transition-colors ${
              activeTab === 'profile' ? 'bg-surface border-t-2 border-t-primary border-x border-x-surface-border text-slate-900 -mb-[1px] pb-[13px]' : 'text-surface-muted hover:text-slate-900'
            }`}
          >
            <User size={18} />
            Profile
          </button>
          
          {isAdmin && (
            <>
              <button
                onClick={() => setActiveTab('users')}
                className={`flex items-center gap-2 px-6 py-3 text-sm font-medium transition-colors ${
                  activeTab === 'users' ? 'bg-surface border-t-2 border-t-primary border-x border-x-surface-border text-slate-900 -mb-[1px] pb-[13px]' : 'text-surface-muted hover:text-slate-900'
                }`}
              >
                <Users size={18} />
                User Management
              </button>
              
              <button
                onClick={() => setActiveTab('approvals')}
                className={`flex items-center gap-2 px-6 py-3 text-sm font-medium transition-colors ${
                  activeTab === 'approvals' ? 'bg-surface border-t-2 border-t-primary border-x border-x-surface-border text-slate-900 -mb-[1px] pb-[13px]' : 'text-surface-muted hover:text-slate-900'
                }`}
              >
                <ClipboardCheck size={18} />
                Pending Approvals
                {pendingCount > 0 && (
                  <span className="ml-2 bg-primary text-white text-[10px] font-bold px-2 py-0.5 rounded-full">
                    {pendingCount}
                  </span>
                )}
              </button>
            </>
          )}
        </div>
        
        <div className="flex-1 p-6 bg-surface overflow-y-auto">
          {activeTab === 'profile' && <ProfileTab />}
          {isAdmin && activeTab === 'users' && <UserManagementTab />}
          {isAdmin && activeTab === 'approvals' && (
            <PendingApprovalsTab onCountChange={setPendingCount} />
          )}
        </div>
      </div>
    </ModalOverlay>
  );
};
