import { useState, useEffect } from 'react';
import { api } from '../apiClient';
import {
  Trash2, User, Phone, MapPin, Building2, Search,
  Mail, ShieldCheck, Clock, Users, ChevronDown, ChevronUp,
  Briefcase, Hash, CheckCircle2, AlertCircle, X, Loader2
} from 'lucide-react';

export default function CustomerManager() {
  const [customers, setCustomers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [expandedId, setExpandedId] = useState(null);
  const [deletingId, setDeletingId] = useState(null);
  const [toast, setToast] = useState(null);

  const showToast = (type, msg) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  useEffect(() => { fetchCustomers(); }, []);

  const fetchCustomers = async () => {
    setLoading(true);
    try {
      const { customers: data } = await api.get('/customers');
      setCustomers((data || []).slice().sort((a, b) => new Date(b.updated_at) - new Date(a.updated_at)));
    } catch (error) {
      console.error('Error fetching customers:', error);
      showToast('error', 'Failed to load customers: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (customer) => {
    if (!window.confirm(`Delete ${customer.first_name || 'this user'}'s account? This cannot be undone.`)) return;
    setDeletingId(customer.id);
    try {
      await api.delete(`/customers/${customer.id}`);
      setCustomers(prev => prev.filter(c => c.id !== customer.id));
      showToast('success', 'Customer deleted successfully.');
    } catch (err) {
      showToast('error', 'Failed to delete: ' + err.message);
    }
    setDeletingId(null);
  };

  const filtered = customers.filter(c => {
    const term = searchTerm.toLowerCase();
    const name = `${c.first_name || ''} ${c.last_name || ''}`.toLowerCase();
    return name.includes(term) ||
      (c.email || '').toLowerCase().includes(term) ||
      (c.phone || '').includes(term) ||
      (c.company_type || '').toLowerCase().includes(term);
  });

  const verified = customers.filter(c => c.onboarding_complete).length;
  const pending = customers.length - verified;

  const initials = (c) => {
    const f = c.first_name?.[0] || '';
    const l = c.last_name?.[0] || '';
    return (f + l).toUpperCase() || '?';
  };

  const formatDate = (d) => d ? new Date(d).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : '—';

  return (
    <div className="w-full max-w-6xl space-y-6 font-sans">

      {/* Toast */}
      {toast && (
        <div className={`fixed top-5 right-5 z-50 flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium border shadow-lg animate-in slide-in-from-top-2 duration-200 ${
          toast.type === 'success' ? 'bg-emerald-50 text-emerald-700 border-emerald-200' : 'bg-rose-50 text-rose-700 border-rose-200'
        }`}>
          {toast.type === 'success' ? <CheckCircle2 size={16} /> : <AlertCircle size={16} />}
          <span>{toast.msg}</span>
          <button onClick={() => setToast(null)} className="ml-2 opacity-60 hover:opacity-100 cursor-pointer"><X size={14} /></button>
        </div>
      )}

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-5 border-b border-slate-100">
        <div>
          <h2 className="text-xl font-bold text-slate-900 tracking-tight flex items-center gap-2">
            <Users size={20} className="text-rose-500" />
            Customer Management
          </h2>
          <p className="text-slate-500 text-sm mt-0.5">All registered users from the mobile app</p>
        </div>
        <button
          onClick={fetchCustomers}
          className="flex items-center gap-2 px-4 py-2 bg-rose-50 hover:bg-rose-100 text-rose-600 font-semibold text-sm rounded-xl transition-all cursor-pointer border border-rose-100"
        >
          <Loader2 size={14} className={loading ? 'animate-spin' : ''} />
          Refresh
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4">
        {[
          { label: 'Total Customers', value: customers.length, color: 'bg-slate-900 text-white', icon: <Users size={18} /> },
          { label: 'Verified', value: verified, color: 'bg-emerald-50 text-emerald-700', icon: <ShieldCheck size={18} className="text-emerald-500" /> },
          { label: 'Pending Profile', value: pending, color: 'bg-amber-50 text-amber-700', icon: <Clock size={18} className="text-amber-500" /> },
        ].map(stat => (
          <div key={stat.label} className={`${stat.color} rounded-2xl p-4 flex items-center gap-3`}>
            <div>{stat.icon}</div>
            <div>
              <p className="text-2xl font-bold leading-none">{stat.value}</p>
              <p className="text-xs font-medium opacity-70 mt-0.5">{stat.label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Search */}
      <div className="relative">
        <Search size={16} className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" />
        <input
          type="text"
          placeholder="Search by name, email, phone or company…"
          value={searchTerm}
          onChange={e => setSearchTerm(e.target.value)}
          className="w-full pl-11 pr-4 py-3 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-rose-500/20 focus:border-rose-400 transition-all"
        />
        {searchTerm && (
          <button onClick={() => setSearchTerm('')} className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 cursor-pointer">
            <X size={14} />
          </button>
        )}
      </div>

      {/* Customer Cards */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-24 gap-3 text-slate-400">
          <Loader2 className="animate-spin text-rose-400" size={32} />
          <p className="text-sm">Loading customers…</p>
        </div>
      ) : filtered.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-24 bg-white rounded-2xl border border-dashed border-slate-200 text-slate-400 gap-2">
          <Users size={32} />
          <p className="text-sm font-medium">{searchTerm ? 'No customers match your search' : 'No customers yet'}</p>
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map(customer => {
            const isExpanded = expandedId === customer.id;
            const isDeleting = deletingId === customer.id;
            return (
              <div
                key={customer.id}
                className={`bg-white rounded-2xl border transition-all overflow-hidden ${
                  isExpanded ? 'border-rose-200 shadow-md shadow-rose-50' : 'border-slate-200 hover:border-slate-300 hover:shadow-sm'
                }`}
              >
                {/* Card Header (always visible) */}
                <div
                  className="flex items-center gap-4 p-4 cursor-pointer select-none"
                  onClick={() => setExpandedId(isExpanded ? null : customer.id)}
                >
                  {/* Avatar */}
                  <div className="w-11 h-11 rounded-full bg-gradient-to-br from-rose-500 to-rose-600 text-white flex items-center justify-center font-bold text-sm flex-shrink-0 shadow-sm">
                    {initials(customer)}
                  </div>

                  {/* Name + Email */}
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-slate-900 text-sm truncate">
                      {customer.first_name} {customer.last_name}
                    </p>
                    <p className="text-xs text-slate-500 truncate flex items-center gap-1 mt-0.5">
                      <Mail size={11} />
                      {customer.email || customer.work_email || '—'}
                    </p>
                  </div>

                  {/* Phone */}
                  <div className="hidden sm:flex items-center gap-1.5 text-sm text-slate-600">
                    <Phone size={13} className="text-slate-400" />
                    <span className="font-medium">{customer.phone || '—'}</span>
                  </div>

                  {/* Status Badge */}
                  <div className="flex-shrink-0">
                    {customer.onboarding_complete ? (
                      <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-100">
                        <ShieldCheck size={11} />
                        Verified
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-amber-50 text-amber-700 border border-amber-100">
                        <Clock size={11} />
                        Pending
                      </span>
                    )}
                  </div>

                  {/* Expand Arrow */}
                  <div className="text-slate-400 flex-shrink-0">
                    {isExpanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                  </div>
                </div>

                {/* Expanded Details */}
                {isExpanded && (
                  <div className="border-t border-slate-100 px-4 pb-4 pt-4 animate-in slide-in-from-top-2 duration-200">
                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-4">

                      {/* Contact */}
                      <div className="bg-slate-50 rounded-xl p-3 space-y-2">
                        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Contact Info</p>
                        <div className="space-y-1.5">
                          <div className="flex items-center gap-2 text-sm text-slate-700">
                            <Mail size={13} className="text-rose-400 flex-shrink-0" />
                            <span className="truncate">{customer.email || customer.work_email || '—'}</span>
                          </div>
                          <div className="flex items-center gap-2 text-sm text-slate-700">
                            <Phone size={13} className="text-rose-400 flex-shrink-0" />
                            <span>{customer.phone || '—'}</span>
                          </div>
                        </div>
                      </div>

                      {/* Business */}
                      <div className="bg-slate-50 rounded-xl p-3 space-y-2">
                        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Business</p>
                        <div className="space-y-1.5">
                          <div className="flex items-center gap-2 text-sm text-slate-700">
                            <Building2 size={13} className="text-rose-400 flex-shrink-0" />
                            <span>{customer.company_type || '—'}</span>
                          </div>
                          <div className="flex items-center gap-2 text-sm text-slate-700">
                            <Briefcase size={13} className="text-rose-400 flex-shrink-0" />
                            <span>{customer.role || '—'}</span>
                          </div>
                          {customer.gst_number && (
                            <div className="flex items-center gap-2 text-xs text-slate-600 font-mono bg-white border border-slate-200 px-2 py-1 rounded-lg">
                              <Hash size={11} className="text-rose-400" />
                              {customer.gst_number}
                            </div>
                          )}
                        </div>
                      </div>

                      {/* Address & Activity */}
                      <div className="bg-slate-50 rounded-xl p-3 space-y-2">
                        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Address & Activity</p>
                        <div className="space-y-1.5">
                          {customer.address && (
                            <div className="flex items-start gap-2 text-sm text-slate-700">
                              <MapPin size={13} className="text-rose-400 flex-shrink-0 mt-0.5" />
                              <span className="line-clamp-2 text-xs leading-relaxed">{customer.address}</span>
                            </div>
                          )}
                          <div className="flex items-center gap-2 text-xs text-slate-500">
                            <Clock size={11} className="text-rose-400" />
                            Last active: {formatDate(customer.updated_at)}
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* Delete Action */}
                    <div className="flex justify-end pt-2 border-t border-slate-100">
                      <button
                        onClick={() => handleDelete(customer)}
                        disabled={isDeleting}
                        className="flex items-center gap-2 px-4 py-2 text-xs font-semibold text-rose-600 hover:text-white bg-rose-50 hover:bg-rose-500 border border-rose-200 hover:border-rose-500 rounded-xl transition-all cursor-pointer disabled:opacity-50"
                      >
                        {isDeleting ? <Loader2 size={13} className="animate-spin" /> : <Trash2 size={13} />}
                        {isDeleting ? 'Deleting…' : 'Delete Account'}
                      </button>
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* Footer Count */}
      {!loading && filtered.length > 0 && (
        <p className="text-xs text-slate-400 text-center">
          Showing {filtered.length} of {customers.length} customers
        </p>
      )}
    </div>
  );
}
