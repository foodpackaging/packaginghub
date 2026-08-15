import { useEffect, useMemo, useState } from 'react';
import { api } from '../apiClient';
import {
  Loader2, RefreshCcw, Search, RotateCcw, CheckCircle, XCircle,
  PackageCheck, Truck, Home, CalendarDays, ChevronDown, ChevronUp,
  AlertCircle, User, Phone, Mail, ShoppingBag, Clock,
} from 'lucide-react';

const money = (value) => `Rs. ${Number(value || 0).toFixed(2)}`;

const STATUS_META = {
  pending:           { label: 'Pending Review',      color: 'amber',   bg: 'bg-amber-50',   text: 'text-amber-700',   border: 'border-amber-200' },
  approved:          { label: 'Approved',             color: 'blue',    bg: 'bg-blue-50',    text: 'text-blue-700',    border: 'border-blue-200' },
  rejected:          { label: 'Rejected',             color: 'rose',    bg: 'bg-rose-50',    text: 'text-rose-700',    border: 'border-rose-200' },
  pickup_scheduled:  { label: 'Pickup Scheduled',     color: 'purple',  bg: 'bg-purple-50',  text: 'text-purple-700',  border: 'border-purple-200' },
  drop_off_pending:  { label: 'Drop-off Pending',     color: 'purple',  bg: 'bg-purple-50',  text: 'text-purple-700',  border: 'border-purple-200' },
  received:          { label: 'Item Received',        color: 'teal',    bg: 'bg-teal-50',    text: 'text-teal-700',    border: 'border-teal-200' },
  refunded:          { label: 'Refunded ✓',           color: 'emerald', bg: 'bg-emerald-50', text: 'text-emerald-700', border: 'border-emerald-200' },
};

const StatusBadge = ({ status }) => {
  const meta = STATUS_META[status] || { label: status, bg: 'bg-slate-50', text: 'text-slate-600', border: 'border-slate-200' };
  return (
    <span className={`px-2.5 py-1 rounded-lg border text-[11px] font-bold uppercase tracking-wide ${meta.bg} ${meta.text} ${meta.border}`}>
      {meta.label}
    </span>
  );
};

const InfoRow = ({ icon: Icon, label, value }) => (
  <div className="flex items-start gap-2 text-sm">
    <Icon size={14} className="text-slate-400 mt-0.5 shrink-0" />
    <div>
      <span className="text-slate-400 mr-1">{label}:</span>
      <span className="text-slate-700 font-medium">{value || '—'}</span>
    </div>
  </div>
);

// ── Main Component ────────────────────────────────────────────────────────────

const ReturnManager = () => {
  const [returns, setReturns] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [error, setError] = useState('');
  const [filterStatus, setFilterStatus] = useState('all');

  const fetchReturns = async () => {
    setError('');
    setLoading(true);

    try {
      const [{ return_requests: returnRows }, { customers }] = await Promise.all([
        api.get('/returns/admin/all'),
        api.get('/customers'),
      ]);

      const orderIds = [...new Set((returnRows || []).map(r => r.order_id).filter(Boolean))];
      const orderResults = await Promise.all(
        orderIds.map((id) => api.get(`/orders/${id}`).then((r) => r.order).catch(() => null))
      );

      const ordersMap = new Map(orderResults.filter(Boolean).map((o) => [o.id, o]));
      const profilesMap = new Map((customers || []).map(p => [p.id, p]));

      const merged = (returnRows || []).map(r => ({
        ...r,
        order: ordersMap.get(r.order_id),
        profile: profilesMap.get(r.user_id),
        orderItems: ordersMap.get(r.order_id)?.items || [],
      }));

      setReturns(merged);
    } catch (err) {
      setError(err.message);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchReturns();
    const interval = window.setInterval(fetchReturns, 30000);
    return () => window.clearInterval(interval);
  }, []);

  const filtered = useMemo(() => {
    let rows = returns;
    if (filterStatus !== 'all') rows = rows.filter(r => r.status === filterStatus);
    const q = search.trim().toLowerCase();
    if (!q) return rows;
    return rows.filter(r => {
      const profile = r.profile || {};
      const name = `${profile.first_name || ''} ${profile.last_name || ''}`;
      return [name, profile.email, profile.phone, r.order?.order_number, r.reason, r.status]
        .filter(Boolean).some(v => String(v).toLowerCase().includes(q));
    });
  }, [returns, search, filterStatus]);

  const updateReturn = async (id, fields) => {
    try {
      await api.patch(`/returns/${id}`, fields);
      await fetchReturns();
    } catch (err) {
      setError(err.message);
    }
  };

  const statusTabs = ['all', 'pending', 'approved', 'pickup_scheduled', 'drop_off_pending', 'received', 'refunded', 'rejected'];

  const counts = useMemo(() => {
    const c = { all: returns.length };
    returns.forEach(r => { c[r.status] = (c[r.status] || 0) + 1; });
    return c;
  }, [returns]);

  return (
    <div className="w-full space-y-8 font-sans animate-in fade-in duration-500">
      {/* Header */}
      <div className="flex flex-col gap-4 pb-6 border-b border-slate-100 md:flex-row md:items-end md:justify-between">
        <div>
          <h2 className="text-xl font-bold text-slate-900 tracking-tight flex items-center gap-2">
            <RotateCcw size={20} className="text-indigo-600" />
            Returns & Refunds
          </h2>
          <p className="text-slate-500 text-sm font-normal">Review customer return requests and manage refunds.</p>
        </div>
        <button
          onClick={fetchReturns}
          className="inline-flex items-center justify-center gap-2 px-3.5 py-2.5 bg-slate-50 hover:bg-slate-100 text-slate-600 rounded-xl text-sm font-semibold transition-all cursor-pointer"
        >
          <RefreshCcw size={15} />
          Refresh
        </button>
      </div>

      {/* Status filter tabs */}
      <div className="flex gap-2 flex-wrap">
        {statusTabs.map(tab => {
          const meta = STATUS_META[tab];
          const isActive = filterStatus === tab;
          const count = counts[tab] || 0;
          return (
            <button
              key={tab}
              onClick={() => setFilterStatus(tab)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all border cursor-pointer ${
                isActive
                  ? 'bg-indigo-600 text-white border-indigo-600'
                  : 'bg-white text-slate-500 border-slate-200 hover:border-indigo-200 hover:text-indigo-600'
              }`}
            >
              {tab === 'all' ? 'All' : (meta?.label || tab)} {count > 0 && `(${count})`}
            </button>
          );
        })}
      </div>

      {/* Search */}
      <div className="relative max-w-md">
        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
        <input
          value={search}
          onChange={e => setSearch(e.target.value)}
          placeholder="Search by customer, order, or reason..."
          className="w-full pl-10 pr-4 py-3 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/10"
        />
      </div>

      {error && (
        <div className="p-3.5 rounded-xl bg-rose-50 text-rose-600 border border-rose-100 text-sm font-medium flex items-center gap-2">
          <AlertCircle size={16} />
          {error}
        </div>
      )}

      {/* Content */}
      {loading ? (
        <div className="p-16 text-center text-slate-400 flex flex-col items-center gap-3">
          <Loader2 className="animate-spin text-indigo-600" size={28} />
          <p className="text-sm">Loading return requests...</p>
        </div>
      ) : filtered.length === 0 ? (
        <div className="p-20 text-center text-slate-400 bg-white rounded-2xl border border-slate-200 border-dashed text-sm flex flex-col items-center gap-3">
          <RotateCcw size={32} className="text-slate-300" />
          No return requests found.
        </div>
      ) : (
        <div className="space-y-4">
          {filtered.map(ret => (
            <ReturnCard key={ret.id} returnReq={ret} onUpdate={updateReturn} />
          ))}
        </div>
      )}
    </div>
  );
};

// ── Return Card ───────────────────────────────────────────────────────────────

const ReturnCard = ({ returnReq: ret, onUpdate }) => {
  const [expanded, setExpanded] = useState(false);
  const [pickupDate, setPickupDate] = useState('');
  const [saving, setSaving] = useState(false);
  const [adminNotes, setAdminNotes] = useState(ret.admin_notes || '');
  const [showNotesInput, setShowNotesInput] = useState(false);

  const profile = ret.profile || {};
  const order   = ret.order || {};
  const customerName = `${profile.first_name || ''} ${profile.last_name || ''}`.trim() || 'Customer';

  const handle = async (fields) => {
    setSaving(true);
    await onUpdate(ret.id, fields);
    setSaving(false);
  };

  const handleApprove = () => handle({ status: 'approved' });
  const handleReject  = () => handle({ status: 'rejected' });
  const handleDropOff = () => handle({ status: 'drop_off_pending', return_method: 'drop_off' });
  const handlePickup  = () => {
    if (!pickupDate) return;
    handle({ status: 'pickup_scheduled', return_method: 'pickup', pickup_date: pickupDate });
  };
  const handleReceived = () => handle({ status: 'received' });
  const handleRefunded = () => handle({ status: 'refunded' });
  const handleSaveNotes = () => {
    handle({ admin_notes: adminNotes });
    setShowNotesInput(false);
  };

  return (
    <div className="bg-white border border-slate-100 rounded-2xl shadow-sm overflow-hidden">
      {/* Card Header */}
      <div className="p-5">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
          <div className="space-y-2 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-sm font-bold text-slate-900">
                Return #{ret.id.slice(0, 8).toUpperCase()}
              </span>
              {order.order_number && (
                <span className="text-xs text-slate-400 font-medium">
                  → Order #{order.order_number}
                </span>
              )}
              <StatusBadge status={ret.status} />
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2">
              <InfoRow icon={User}       label="Customer"  value={customerName} />
              <InfoRow icon={Phone}      label="Phone"     value={profile.phone} />
              <InfoRow icon={Mail}       label="Email"     value={profile.email} />
              <InfoRow icon={ShoppingBag} label="Order Total" value={money(order.total_amount)} />
              <InfoRow icon={Clock}      label="Requested" value={new Date(ret.created_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })} />
            </div>

            {/* Return Reason */}
            <div className="mt-2 p-3 bg-slate-50 rounded-xl border border-slate-100">
              <p className="text-xs font-bold text-slate-500 uppercase tracking-wide mb-1">Return Reason</p>
              <p className="text-sm text-slate-700 leading-relaxed">{ret.reason}</p>
            </div>

            {/* Returned Items + Refund */}
            {ret.return_items && ret.return_items.length > 0 && (
              <div className="mt-2 p-3 bg-rose-50 rounded-xl border border-rose-100">
                <p className="text-xs font-bold text-rose-500 uppercase tracking-wide mb-2">Returned Items</p>
                <div className="space-y-1.5">
                  {ret.return_items.map((item, idx) => (
                    <div key={idx} className="flex items-start justify-between gap-3">
                      <div>
                        <p className="text-sm font-semibold text-slate-700">{item.quantity}x {item.product_name}</p>
                        <p className="text-xs text-slate-400">Item total: {money(item.item_total)}</p>
                      </div>
                      <span className="text-sm font-bold text-emerald-600 shrink-0">{money(item.refund_amount)}</span>
                    </div>
                  ))}
                </div>
                <div className="mt-3 pt-2 border-t border-rose-200 flex items-center justify-between">
                  <span className="text-xs font-bold text-slate-600 uppercase tracking-wide">Total Refund</span>
                  <span className="text-base font-bold text-emerald-600">{money(ret.refund_amount)}</span>
                </div>
              </div>
            )}

            {/* Admin Notes */}
            {ret.admin_notes && !showNotesInput && (
              <div className="p-3 bg-indigo-50 rounded-xl border border-indigo-100">
                <p className="text-xs font-bold text-indigo-500 uppercase tracking-wide mb-1">Admin Note</p>
                <p className="text-sm text-indigo-700">{ret.admin_notes}</p>
              </div>
            )}
            {showNotesInput && (
              <div className="space-y-2">
                <textarea
                  className="w-full p-3 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-indigo-400 resize-none"
                  rows={2}
                  placeholder="Add a note visible to admin only..."
                  value={adminNotes}
                  onChange={e => setAdminNotes(e.target.value)}
                />
                <div className="flex gap-2">
                  <button onClick={handleSaveNotes} disabled={saving} className="px-3 py-1.5 bg-indigo-600 text-white rounded-lg text-xs font-bold cursor-pointer hover:bg-indigo-700 transition-colors">Save Note</button>
                  <button onClick={() => setShowNotesInput(false)} className="px-3 py-1.5 bg-slate-100 text-slate-500 rounded-lg text-xs font-bold cursor-pointer hover:bg-slate-200 transition-colors">Cancel</button>
                </div>
              </div>
            )}
          </div>

          {/* Expand toggle */}
          <button
            onClick={() => setExpanded(p => !p)}
            className="flex items-center gap-1.5 text-xs text-slate-400 hover:text-slate-600 font-medium cursor-pointer transition-colors self-start"
          >
            {expanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
            {expanded ? 'Less' : 'Order items'}
          </button>
        </div>

        {/* Expanded: order items */}
        {expanded && (
          <div className="mt-4 border border-slate-100 rounded-xl overflow-hidden">
            {(ret.orderItems || []).map(item => (
              <div key={item.id} className="flex justify-between gap-3 px-4 py-2.5 text-sm border-b border-slate-50 last:border-b-0">
                <span className="text-slate-600">{item.product_name} × {item.quantity}</span>
                <span className="font-semibold text-slate-900">{money(item.total_price)}</span>
              </div>
            ))}
            {(!ret.orderItems || ret.orderItems.length === 0) && (
              <div className="px-4 py-3 text-sm text-slate-400">No items loaded.</div>
            )}
          </div>
        )}
      </div>

      {/* Action Bar */}
      <div className="border-t border-slate-50 bg-slate-50/60 px-5 py-4">
        <ActionBar
          ret={ret}
          saving={saving}
          pickupDate={pickupDate}
          setPickupDate={setPickupDate}
          onApprove={handleApprove}
          onReject={handleReject}
          onDropOff={handleDropOff}
          onPickup={handlePickup}
          onReceived={handleReceived}
          onRefunded={handleRefunded}
          onAddNote={() => setShowNotesInput(true)}
        />
      </div>
    </div>
  );
};

// ── Action Bar ────────────────────────────────────────────────────────────────

const ActionBar = ({ ret, saving, pickupDate, setPickupDate, onApprove, onReject, onDropOff, onPickup, onReceived, onRefunded, onAddNote }) => {
  const Btn = ({ onClick, children, color = 'indigo', disabled }) => {
    const palette = {
      indigo:  'bg-indigo-600 hover:bg-indigo-700 text-white',
      emerald: 'bg-emerald-600 hover:bg-emerald-700 text-white',
      rose:    'bg-rose-600 hover:bg-rose-700 text-white',
      slate:   'bg-slate-100 hover:bg-slate-200 text-slate-700',
      amber:   'bg-amber-500 hover:bg-amber-600 text-white',
      purple:  'bg-purple-600 hover:bg-purple-700 text-white',
      teal:    'bg-teal-600 hover:bg-teal-700 text-white',
    };
    return (
      <button
        onClick={onClick}
        disabled={disabled || saving}
        className={`inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer disabled:opacity-50 ${palette[color]}`}
      >
        {saving ? <Loader2 size={13} className="animate-spin" /> : children}
      </button>
    );
  };

  // PENDING: Approve / Reject
  if (ret.status === 'pending') {
    return (
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-xs text-slate-400 font-medium mr-1">Action required:</span>
        <Btn onClick={onApprove} color="emerald">
          <CheckCircle size={13} /> Approve Return
        </Btn>
        <Btn onClick={onReject} color="rose">
          <XCircle size={13} /> Reject Return
        </Btn>
        <Btn onClick={onAddNote} color="slate">Add Note</Btn>
      </div>
    );
  }

  // APPROVED: Choose return method
  if (ret.status === 'approved') {
    return (
      <div className="space-y-3">
        <p className="text-xs font-semibold text-slate-600">Choose how the customer will return the item:</p>
        <div className="flex flex-wrap gap-2 items-end">
          <Btn onClick={onDropOff} color="purple">
            <Home size={13} /> Customer Drops Off
          </Btn>
          <div className="flex items-center gap-2">
            <div className="flex items-center gap-2 bg-white border border-slate-200 rounded-xl px-3 py-2">
              <CalendarDays size={13} className="text-slate-400" />
              <input
                type="date"
                value={pickupDate}
                min={new Date().toISOString().split('T')[0]}
                onChange={e => setPickupDate(e.target.value)}
                className="text-xs text-slate-700 focus:outline-none bg-transparent"
              />
            </div>
            <Btn onClick={onPickup} color="purple" disabled={!pickupDate}>
              <Truck size={13} /> Schedule Pickup
            </Btn>
          </div>
        </div>
      </div>
    );
  }

  // PICKUP_SCHEDULED
  if (ret.status === 'pickup_scheduled') {
    return (
      <div className="flex flex-wrap items-center gap-3">
        <div className="flex items-center gap-2 text-purple-700 bg-purple-50 rounded-xl px-3 py-2 border border-purple-100">
          <CalendarDays size={13} />
          <span className="text-xs font-semibold">
            Pickup: {ret.pickup_date ? new Date(ret.pickup_date).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : '—'}
          </span>
        </div>
        <Btn onClick={onReceived} color="teal">
          <PackageCheck size={13} /> Mark as Picked Up & Received
        </Btn>
      </div>
    );
  }

  // DROP_OFF_PENDING
  if (ret.status === 'drop_off_pending') {
    return (
      <div className="flex flex-wrap items-center gap-3">
        <div className="flex items-center gap-2 text-purple-700 bg-purple-50 rounded-xl px-3 py-2 border border-purple-100">
          <Home size={13} />
          <span className="text-xs font-semibold">Awaiting customer drop-off</span>
        </div>
        <Btn onClick={onReceived} color="teal">
          <PackageCheck size={13} /> Mark as Received at Store
        </Btn>
      </div>
    );
  }

  // RECEIVED
  if (ret.status === 'received') {
    return (
      <div className="flex flex-wrap items-center gap-3">
        <div className="flex items-center gap-2 text-teal-700 bg-teal-50 rounded-xl px-3 py-2 border border-teal-100 text-xs font-semibold">
          <PackageCheck size={13} />
          Item received — initiate refund
        </div>
        <Btn onClick={onRefunded} color="emerald">
          <CheckCircle size={13} /> Mark Refund Initiated
        </Btn>
      </div>
    );
  }

  // REFUNDED
  if (ret.status === 'refunded') {
    return (
      <div className="flex items-center gap-2 text-emerald-700 bg-emerald-50 rounded-xl px-3 py-2 border border-emerald-100 text-xs font-semibold w-fit">
        <CheckCircle size={13} />
        Refund has been initiated successfully.
      </div>
    );
  }

  // REJECTED
  if (ret.status === 'rejected') {
    return (
      <div className="flex items-center gap-2 text-rose-600 text-xs font-semibold">
        <XCircle size={13} />
        This return request was rejected.
        <button onClick={onAddNote} className="ml-2 text-slate-400 hover:text-slate-600 font-medium cursor-pointer transition-colors">Add note</button>
      </div>
    );
  }

  return null;
};

export default ReturnManager;
