import React, { useState, useEffect } from 'react';
import { useToast } from '../Toast';
import { Check, X, ClipboardCheck } from 'lucide-react';

interface PendingUser {
  id: string;
  username: string;
  email: string;
  requestedRole: string;
  createdAt: string;
}

interface Props {
  onCountChange: (count: number) => void;
}

export const PendingApprovalsTab: React.FC<Props> = ({ onCountChange }) => {
  const toast = useToast();
  const [pendingUsers, setPendingUsers] = useState<PendingUser[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchPending();
  }, []);

  const fetchPending = async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/users/pending');
      if (res.ok) {
        const data = await res.json();
        const users = data.users || data;
        setPendingUsers(users);
        onCountChange(users.length);
      }
    } catch (err) {
      toast.error('Failed to load pending approvals');
    } finally {
      setLoading(false);
    }
  };

  const handleAction = async (userId: string, action: 'approve' | 'reject') => {
    try {
      const res = await fetch(`/api/users/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId }),
      });
      
      if (res.ok) {
        toast.success(`User ${action}d successfully`);
        fetchPending();
      } else {
        const err = await res.json().catch(() => ({}));
        toast.error(err.message || `Failed to ${action} user`);
      }
    } catch (err) {
      toast.error('Network error occurred');
    }
  };

  if (loading) {
    return <div className="p-8 text-center text-surface-muted">Loading pending users...</div>;
  }

  return (
    <div className="space-y-6">
      <h3 className="text-lg font-bold">Pending Approvals</h3>
      
      {pendingUsers.length === 0 ? (
        <div className="flex flex-col items-center justify-center p-12 bg-base-light border border-surface-border rounded-lg text-surface-muted">
          <ClipboardCheck size={48} className="mb-4 opacity-50" />
          <p className="font-medium">No pending registrations</p>
          <p className="text-sm mt-1">All user requests have been processed.</p>
        </div>
      ) : (
        <div className="grid gap-4">
          {pendingUsers.map(u => (
            <div key={u.id} className="flex items-center justify-between p-4 bg-base-light border border-surface-border rounded-lg">
              <div>
                <div className="flex items-center gap-2 mb-1">
                  <h4 className="font-bold text-slate-900">{u.username}</h4>
                  <span className="text-xs text-surface-muted">•</span>
                  <span className="text-sm text-surface-muted">{u.email}</span>
                </div>
                <div className="flex items-center gap-3 text-sm">
                  <span className="text-[10px] font-bold uppercase tracking-wider text-surface-muted">Requested Role:</span>
                  <span className="px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider bg-surface border border-surface-border rounded">
                    {u.requestedRole || 'viewer'}
                  </span>
                  <span className="text-[10px] font-bold uppercase tracking-wider text-surface-muted ml-2">Requested On:</span>
                  <span className="text-xs text-slate-900">
                    {new Date(u.createdAt).toLocaleDateString()}
                  </span>
                </div>
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => handleAction(u.id, 'approve')}
                  className="flex items-center gap-1.5 px-3 py-1.5 bg-green-500 hover:bg-green-600 text-white text-sm font-medium rounded transition-colors"
                >
                  <Check size={16} />
                  Approve
                </button>
                <button
                  onClick={() => handleAction(u.id, 'reject')}
                  className="flex items-center gap-1.5 px-3 py-1.5 bg-primary hover:bg-primary-dark text-white text-sm font-medium rounded transition-colors"
                >
                  <X size={16} />
                  Reject
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
