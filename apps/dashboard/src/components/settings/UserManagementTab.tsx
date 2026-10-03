import React, { useState, useEffect } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { useToast } from '../Toast';
import { Pencil, Trash2, Plus, X, Save } from 'lucide-react';

interface UserData {
  id: string;
  username: string;
  email: string;
  role: string;
  status: string;
  createdAt: string;
}

export const UserManagementTab: React.FC = () => {
  const { user } = useAuth();
  const toast = useToast();
  
  const [users, setUsers] = useState<UserData[]>([]);
  const [loading, setLoading] = useState(true);
  
  const [showAddForm, setShowAddForm] = useState(false);
  const [formData, setFormData] = useState({ username: '', email: '', password: '', role: 'viewer' });
  
  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/users');
      if (res.ok) {
        const data = await res.json();
        setUsers(data.users || data);
      }
    } catch (err) {
      toast.error('Failed to load users');
    } finally {
      setLoading(false);
    }
  };

  const handleAddUser = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const res = await fetch('/api/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData),
      });
      if (res.ok) {
        toast.success('User created successfully');
        setShowAddForm(false);
        setFormData({ username: '', email: '', password: '', role: 'viewer' });
        fetchUsers();
      } else {
        const err = await res.json().catch(() => ({}));
        toast.error(err.message || 'Failed to create user');
      }
    } catch (err) {
      toast.error('Network error occurred');
    }
  };

  const handleDelete = async (id: string) => {
    if (Number(id) === user?.id) {
      toast.error('You cannot delete your own account');
      return;
    }
    if (!window.confirm('Are you sure you want to delete this user?')) return;
    
    try {
      const res = await fetch(`/api/users/${id}`, { method: 'DELETE' });
      if (res.ok) {
        toast.success('User deleted successfully');
        fetchUsers();
      } else {
        toast.error('Failed to delete user');
      }
    } catch (err) {
      toast.error('Network error occurred');
    }
  };

  if (loading) {
    return <div className="p-8 text-center text-surface-muted">Loading users...</div>;
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-bold">User Management</h3>
        {!showAddForm && (
          <button
            onClick={() => setShowAddForm(true)}
            className="flex items-center gap-2 px-3 py-1.5 bg-primary text-white text-sm font-medium rounded hover:bg-primary-dark transition-colors"
          >
            <Plus size={16} />
            Add User
          </button>
        )}
      </div>

      {showAddForm && (
        <div className="bg-base-light p-4 rounded-lg border border-surface-border mb-6">
          <div className="flex justify-between items-center mb-4">
            <h4 className="font-bold">Add New User</h4>
            <button onClick={() => setShowAddForm(false)} className="text-surface-muted hover:text-slate-900">
              <X size={16} />
            </button>
          </div>
          <form onSubmit={handleAddUser} className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-[10px] font-bold uppercase tracking-wider text-surface-muted mb-1">Username</label>
              <input required value={formData.username} onChange={e => setFormData({...formData, username: e.target.value})} className="w-full px-3 py-2 bg-surface border border-surface-border rounded text-sm focus:outline-none focus:border-primary" />
            </div>
            <div>
              <label className="block text-[10px] font-bold uppercase tracking-wider text-surface-muted mb-1">Email</label>
              <input type="email" required value={formData.email} onChange={e => setFormData({...formData, email: e.target.value})} className="w-full px-3 py-2 bg-surface border border-surface-border rounded text-sm focus:outline-none focus:border-primary" />
            </div>
            <div>
              <label className="block text-[10px] font-bold uppercase tracking-wider text-surface-muted mb-1">Password</label>
              <input type="password" required value={formData.password} onChange={e => setFormData({...formData, password: e.target.value})} className="w-full px-3 py-2 bg-surface border border-surface-border rounded text-sm focus:outline-none focus:border-primary" />
            </div>
            <div>
              <label className="block text-[10px] font-bold uppercase tracking-wider text-surface-muted mb-1">Role</label>
              <select value={formData.role} onChange={e => setFormData({...formData, role: e.target.value})} className="w-full px-3 py-2 bg-surface border border-surface-border rounded text-sm focus:outline-none focus:border-primary">
                <option value="admin">Admin</option>
                <option value="responder">Responder</option>
                <option value="viewer">Viewer</option>
              </select>
            </div>
            <div className="col-span-2 pt-2">
              <button type="submit" className="flex items-center gap-2 px-4 py-2 bg-primary text-white text-sm font-medium rounded hover:bg-primary-dark transition-colors">
                <Save size={16} /> Save User
              </button>
            </div>
          </form>
        </div>
      )}

      {users.length === 0 ? (
        <div className="text-center p-8 bg-base-light border border-surface-border rounded-lg text-surface-muted">
          No registered users found
        </div>
      ) : (
        <div className="overflow-x-auto border border-surface-border rounded-lg">
          <table className="w-full text-left text-sm whitespace-nowrap">
            <thead className="bg-base-dark text-[10px] uppercase tracking-wider font-bold text-surface-muted">
              <tr>
                <th className="px-4 py-3">Username</th>
                <th className="px-4 py-3">Email</th>
                <th className="px-4 py-3">Role</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-surface-border bg-surface">
              {users.map(u => (
                <tr key={u.id} className="hover:bg-base-dark/50 transition-colors">
                  <td className="px-4 py-3 font-medium">{u.username}</td>
                  <td className="px-4 py-3 text-surface-muted">{u.email}</td>
                  <td className="px-4 py-3">
                    <span className={`inline-block px-2 py-1 text-[10px] font-bold uppercase tracking-wider text-white rounded-md ${
                      u.role === 'admin' ? 'bg-primary' : u.role === 'responder' ? 'bg-blue-500' : 'bg-surface-muted'
                    }`}>
                      {u.role}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-xs">{u.status || 'Active'}</td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <button className="p-1.5 text-surface-muted hover:text-primary transition-colors rounded">
                        <Pencil size={16} />
                      </button>
                      <button 
                        onClick={() => handleDelete(u.id)}
                        disabled={Number(u.id) === user?.id}
                        className="p-1.5 text-surface-muted hover:text-primary transition-colors rounded disabled:opacity-30 disabled:hover:text-surface-muted"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};
