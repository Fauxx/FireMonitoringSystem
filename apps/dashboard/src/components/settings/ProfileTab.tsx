import React, { useState } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { useToast } from '../Toast';
import { Lock, Save, X } from 'lucide-react';

export const ProfileTab: React.FC = () => {
  const { user } = useAuth();
  const toast = useToast();
  const [isEditingPassword, setIsEditingPassword] = useState(false);
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  if (!user) return null;

  const initials = user.username ? user.username.substring(0, 2).toUpperCase() : 'U';
  
  let roleColor = 'bg-surface-muted';
  if (user.role === 'admin') roleColor = 'bg-primary';
  else if (user.role === 'responder') roleColor = 'bg-blue-500';

  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    if (newPassword !== confirmPassword) {
      toast.error('New passwords do not match');
      return;
    }
    
    setIsSubmitting(true);
    try {
      const res = await fetch('/auth/me/password', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ currentPassword, newPassword }),
      });
      
      if (res.ok) {
        toast.success('Password updated successfully');
        setIsEditingPassword(false);
        setCurrentPassword('');
        setNewPassword('');
        setConfirmPassword('');
      } else {
        const err = await res.json().catch(() => ({}));
        toast.error(err.message || 'Failed to update password');
      }
    } catch (err) {
      toast.error('Network error occurred');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto space-y-8">
      <div className="flex items-start gap-6 bg-base-light p-6 rounded-lg border border-surface-border">
        <div className="flex-shrink-0 w-20 h-20 rounded-full bg-slate-200 text-slate-600 flex items-center justify-center text-2xl font-bold">
          {initials}
        </div>
        <div className="flex-1 space-y-2">
          <div className="flex items-center gap-3">
            <h2 className="text-2xl font-bold">{user.username}</h2>
            <span className={`px-2 py-1 text-[10px] font-bold uppercase tracking-wider text-white rounded-md ${roleColor}`}>
              {user.role}
            </span>
          </div>
          <p className="text-surface-muted text-sm">{user.email}</p>
        </div>
      </div>

      <div className="bg-base-light p-6 rounded-lg border border-surface-border">
        <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
          <Lock size={20} className="text-surface-muted" />
          Security Settings
        </h3>
        
        {!isEditingPassword ? (
          <button
            onClick={() => setIsEditingPassword(true)}
            className="px-4 py-2 bg-base-dark border border-surface-border hover:bg-surface-border text-sm font-medium rounded transition-colors"
          >
            Change Password
          </button>
        ) : (
          <form onSubmit={handleChangePassword} className="space-y-4 max-w-sm">
            <div>
              <label className="block text-[10px] font-bold uppercase tracking-wider text-surface-muted mb-1">Current Password</label>
              <input
                type="password"
                required
                value={currentPassword}
                onChange={(e) => setCurrentPassword(e.target.value)}
                className="w-full px-3 py-2 bg-surface border border-surface-border rounded text-sm focus:outline-none focus:border-primary"
              />
            </div>
            <div>
              <label className="block text-[10px] font-bold uppercase tracking-wider text-surface-muted mb-1">New Password</label>
              <input
                type="password"
                required
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                className="w-full px-3 py-2 bg-surface border border-surface-border rounded text-sm focus:outline-none focus:border-primary"
              />
            </div>
            <div>
              <label className="block text-[10px] font-bold uppercase tracking-wider text-surface-muted mb-1">Confirm New Password</label>
              <input
                type="password"
                required
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                className="w-full px-3 py-2 bg-surface border border-surface-border rounded text-sm focus:outline-none focus:border-primary"
              />
            </div>
            <div className="flex gap-2 pt-2">
              <button
                type="submit"
                disabled={isSubmitting}
                className="flex items-center gap-2 px-4 py-2 bg-primary text-white text-sm font-medium rounded hover:bg-primary-dark transition-colors disabled:opacity-50"
              >
                <Save size={16} />
                Save
              </button>
              <button
                type="button"
                onClick={() => {
                  setIsEditingPassword(false);
                  setCurrentPassword('');
                  setNewPassword('');
                  setConfirmPassword('');
                }}
                className="flex items-center gap-2 px-4 py-2 bg-base-dark border border-surface-border text-sm font-medium rounded hover:bg-surface-border transition-colors"
              >
                <X size={16} />
                Cancel
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};
