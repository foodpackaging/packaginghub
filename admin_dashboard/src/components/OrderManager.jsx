import { useEffect, useMemo, useState } from 'react';
import { api } from '../apiClient';
import { Clock, Loader2, MapPin, PackageCheck, RefreshCcw, Search, Truck } from 'lucide-react';

const money = (value) => `Rs. ${Number(value || 0).toFixed(2)}`;

const paymentLabel = (method) => {
  const labels = {
    razorpay: 'Razorpay',
    upi: 'UPI',
    cod: 'Cash on delivery',
    pay_at_store: 'Pay at store',
  };
  return labels[method] || method || 'Not set';
};

const statusClasses = {
  pending: 'bg-amber-50 text-amber-700 border-amber-100',
  processing: 'bg-blue-50 text-blue-700 border-blue-100',
  packed: 'bg-purple-50 text-purple-700 border-purple-100',
  delivered: 'bg-emerald-50 text-emerald-700 border-emerald-100',
  picked_up: 'bg-emerald-50 text-emerald-700 border-emerald-100',
  cancelled: 'bg-rose-50 text-rose-700 border-rose-100',
};

const etaIsoFromNow = (minutes) => new Date(Date.now() + minutes * 60 * 1000).toISOString();

const OrderManager = () => {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [etaValues, setEtaValues] = useState({});
  const [savingEtaId, setSavingEtaId] = useState(null);
  const [error, setError] = useState('');

  const fetchOrders = async () => {
    setError('');
    setLoading(true);

    try {
      const [{ orders: orderRows }, { customers }] = await Promise.all([
        api.get('/orders/admin/all'),
        api.get('/customers'),
      ]);

      const profilesById = new Map((customers || []).map((profile) => [profile.id, profile]));
      const merged = (orderRows || []).map((order) => ({
        ...order,
        profile: profilesById.get(order.user_id),
      }));

      setOrders(merged);
      setEtaValues(
        merged.reduce((acc, order) => {
          if (order.estimated_delivery_time) {
            const d = new Date(order.estimated_delivery_time);
            acc[order.id] = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
          } else {
            acc[order.id] = '';
          }
          return acc;
        }, {})
      );
    } catch (err) {
      setError(err.message);
    }
    setLoading(false);
  };

  useEffect(() => {
    const initialFetch = window.setTimeout(fetchOrders, 0);
    const interval = window.setInterval(fetchOrders, 30000);
    return () => {
      window.clearTimeout(initialFetch);
      window.clearInterval(interval);
    };
  }, []);

  const filteredOrders = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return orders;
    return orders.filter((order) => {
      const profile = order.profile || {};
      const name = `${profile.first_name || ''} ${profile.last_name || ''}`.trim();
      return [order.order_number, name, profile.email, profile.phone, order.status]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(q));
    });
  }, [orders, search]);

  const updateEta = async (orderId, isDelayed = false) => {
    const timeValue = etaValues[orderId];
    if (!timeValue || !timeValue.includes(':')) {
      setError('Enter a valid time (HH:MM).');
      return;
    }

    const [hours, minutes] = timeValue.split(':').map(Number);
    const now = new Date();
    const target = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hours, minutes, 0);

    if (target < now) {
      target.setDate(target.getDate() + 1);
    }

    const diffMinutes = Math.round((target - now) / 60000);

    setSavingEtaId(orderId);
    setError('');
    const currentOrder = orders.find(o => o.id === orderId) || {};
    const deliveryAddress = currentOrder.delivery_address || {};

    try {
      await api.patch(`/orders/${orderId}`, {
        eta_minutes: diffMinutes,
        estimated_delivery_time: target.toISOString(),
        delivery_address: { ...deliveryAddress, is_delayed: isDelayed },
      });
      await fetchOrders();
    } catch (err) {
      setError(err.message);
    }
    setSavingEtaId(null);
  };

  const updateOrderStatus = async (orderId, newStatus, extraFields = {}) => {
    setError('');
    try {
      await api.patch(`/orders/${orderId}`, { status: newStatus, ...extraFields });
      await fetchOrders();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="w-full space-y-8 font-sans animate-in fade-in duration-500">
      <div className="flex flex-col gap-4 pb-6 border-b border-slate-100 md:flex-row md:items-end md:justify-between">
        <div>
          <h2 className="text-xl font-bold text-slate-900 tracking-tight">Orders</h2>
          <p className="text-slate-500 text-sm font-normal">Review new orders and set customer delivery ETAs.</p>
        </div>
        <button
          onClick={fetchOrders}
          className="inline-flex items-center justify-center gap-2 px-3.5 py-2.5 bg-slate-50 hover:bg-slate-100 text-slate-600 rounded-xl text-sm font-semibold transition-all cursor-pointer"
        >
          <RefreshCcw size={15} />
          Refresh
        </button>
      </div>

      <div className="relative max-w-md">
        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
        <input
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="Search order, customer, phone"
          className="w-full pl-10 pr-4 py-3 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/10"
        />
      </div>

      {error && (
        <div className="p-3.5 rounded-xl bg-rose-50 text-rose-600 border border-rose-100 text-sm font-medium">
          {error}
        </div>
      )}

      {loading ? (
        <div className="p-16 text-center text-slate-400 flex flex-col items-center gap-3">
          <Loader2 className="animate-spin text-indigo-600" size={28} />
          <p className="text-sm">Loading orders...</p>
        </div>
      ) : filteredOrders.length === 0 ? (
        <div className="p-20 text-center text-slate-400 bg-white rounded-2xl border border-slate-200 border-dashed text-sm">
          No orders found.
        </div>
      ) : (
        <div className="space-y-4">
          {filteredOrders.map((order) => (
            <OrderCard
              key={order.id}
              order={order}
              etaValue={etaValues[order.id] || ''}
              onEtaChange={(value) => setEtaValues((prev) => ({ ...prev, [order.id]: value }))}
              onSaveEta={(isDelayed) => updateEta(order.id, isDelayed)}
              savingEta={savingEtaId === order.id}
              onUpdateStatus={(status, extra) => updateOrderStatus(order.id, status, extra)}
            />
          ))}
        </div>
      )}
    </div>
  );
};

const OrderCard = ({ order, etaValue, onEtaChange, onSaveEta, savingEta, onUpdateStatus }) => {
  const profile = order.profile || {};
  const customerName = order.delivery_address?.name || `${profile.first_name || ''} ${profile.last_name || ''}`.trim() || 'Customer';
  const address = order.delivery_address?.address || profile.address || null;
  const lat = order.delivery_address?.latitude ?? null;
  const lng = order.delivery_address?.longitude ?? null;
  const mapsUrl = lat != null && lng != null
    ? `https://www.google.com/maps?q=${lat},${lng}`
    : (order.delivery_address?.location_url || profile.location_url || null);
  const isDelivery = order.delivery_method === 'delivery';

  return (
    <div className="bg-white border border-slate-100 rounded-xl p-5 shadow-sm">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div className="space-y-3">
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="text-base font-bold text-slate-900">#{order.order_number}</h3>
            <span className={`px-2 py-1 rounded-lg border text-[11px] font-bold uppercase ${statusClasses[order.status] || statusClasses.pending}`}>
              {order.status}
            </span>
            {order.status === 'pending' && (
              <button
                onClick={() => onUpdateStatus('processing')}
                className="ml-2 px-3 py-1 bg-blue-100 hover:bg-blue-200 text-blue-700 rounded text-xs font-bold transition-colors cursor-pointer"
              >
                Accept Order
              </button>
            )}
            {order.status === 'processing' && !isDelivery && (
              <button
                onClick={() => onUpdateStatus('packed')}
                className="ml-2 px-3 py-1 bg-purple-100 hover:bg-purple-200 text-purple-700 rounded text-xs font-bold transition-colors cursor-pointer"
              >
                Mark as Packed
              </button>
            )}
            {order.status === 'packed' && !isDelivery && (
              <button
                onClick={() => onUpdateStatus('picked_up', { payment_status: 'paid' })}
                className="ml-2 px-3 py-1 bg-emerald-100 hover:bg-emerald-200 text-emerald-700 rounded text-xs font-bold transition-colors cursor-pointer"
              >
                Mark as Paid ✓
              </button>
            )}
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
            <InfoLine label="Customer" value={customerName} />
            <InfoLine label="Phone" value={order.delivery_address?.phone || profile.phone || 'Not provided'} />
            <InfoLine label="Email" value={order.delivery_address?.email || profile.email || 'Not provided'} />
            <InfoLine label="Total" value={money(order.total_amount)} strong />
          </div>
        </div>

        <div className="flex items-center gap-2">
          {isDelivery ? <Truck size={18} className="text-indigo-600" /> : <PackageCheck size={18} className="text-indigo-600" />}
          <div className="text-sm">
            <div className="font-semibold text-slate-800">{isDelivery ? 'Delivery' : 'Pickup'}</div>
            <div className="text-slate-400">{paymentLabel(order.payment_method)}</div>
          </div>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-1 lg:grid-cols-[1fr_280px] gap-4">
        <div className="space-y-3">
          <div className="flex gap-2 text-sm text-slate-600">
            <MapPin size={16} className="text-slate-400 mt-0.5 shrink-0" />
            <div className="flex flex-col gap-1.5">
              {isDelivery ? (
                address ? (
                  <>
                    <span className="leading-snug">
                      {order.delivery_address?.house_number && <span className="font-semibold block">{order.delivery_address.house_number}</span>}
                      {address}
                      {order.delivery_address?.landmark && <span className="block mt-1 text-slate-500">Landmark: {order.delivery_address.landmark}</span>}
                    </span>
                    {lat != null && lng != null && (
                      <span className="text-xs text-indigo-500 mt-1 flex items-center gap-1">
                        GPS: {lat.toFixed(5)}, {lng.toFixed(5)}
                      </span>
                    )}
                  </>
                ) : (
                  <span className="text-slate-400 italic">No address saved.</span>
                )
              ) : (
                <span className="text-slate-500">Customer will pick up from store.</span>
              )}
              {isDelivery && mapsUrl && (
                <a
                  href={mapsUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 mt-1 bg-indigo-50 hover:bg-indigo-100 border border-indigo-200 text-indigo-700 rounded-lg text-xs font-semibold transition-colors w-fit"
                >
                  <MapPin size={12} />
                  Open in Google Maps
                </a>
              )}
            </div>
          </div>

          <div className="border border-slate-100 rounded-xl overflow-hidden">
            {(order.items || []).map((item) => (
              <div key={item.id} className="flex justify-between gap-3 px-3 py-2 text-sm border-b border-slate-50 last:border-b-0">
                <span className="text-slate-700">{item.product_name} x {item.quantity}</span>
                <span className="font-semibold text-slate-900">{money(item.total_price)}</span>
              </div>
            ))}
            {(!order.items || order.items.length === 0) && (
              <div className="px-3 py-2 text-sm text-slate-400">No items loaded.</div>
            )}
          </div>
        </div>

        {isDelivery && (
          <EtaPanel
            order={order}
            etaValue={etaValue}
            onEtaChange={onEtaChange}
            onSaveEta={onSaveEta}
            savingEta={savingEta}
            onUpdateStatus={onUpdateStatus}
          />
        )}
        {!isDelivery && order.status === 'packed' && (
          <div className="bg-emerald-50 border border-emerald-100 rounded-xl p-4 flex items-center gap-3">
            <PackageCheck size={20} className="text-emerald-600 shrink-0" />
            <div>
              <p className="text-sm font-bold text-emerald-800">Order Packed &amp; Ready</p>
              <p className="text-xs text-emerald-600">Customer has been notified to come pick up.</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

const EtaPanel = ({ order, etaValue, onEtaChange, onSaveEta, savingEta, onUpdateStatus }) => {
  const [delayMode, setDelayMode] = useState(false);
  const hasEta = !!order.estimated_delivery_time;
  const isDelayed = !!order.delivery_address?.is_delayed;
  const isDelivered = order.status === 'delivered';
  const etaTimeStr = hasEta
    ? new Date(order.estimated_delivery_time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    : null;

  const handleSet = async () => {
    await onSaveEta(false);
  };

  const handleConfirmDelay = async () => {
    await onSaveEta(true);
    setDelayMode(false);
  };

  if (isDelivered) {
    return (
      <div className="bg-emerald-50 border border-emerald-100 rounded-xl p-4 flex items-center gap-3">
        <PackageCheck size={20} className="text-emerald-600 shrink-0" />
        <div>
          <p className="text-sm font-bold text-emerald-800">Delivered Successfully</p>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-slate-50 rounded-xl p-4 space-y-3">
      <div className="flex items-center gap-2 text-sm font-bold text-slate-800">
        <Clock size={16} className="text-indigo-600" />
        Delivery ETA
      </div>

      {/* State 1: ETA is set, not in delay mode — show time and Delay button */}
      {hasEta && !delayMode && (
        <>
          <div className="space-y-1">
            <p className="text-sm font-semibold text-slate-800">
              Will be delivered at {etaTimeStr}
            </p>
            {isDelayed && (
              <span className="inline-block text-[11px] font-bold uppercase tracking-wide bg-rose-100 text-rose-600 px-2 py-0.5 rounded-md">
                Delayed
              </span>
            )}
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => onUpdateStatus('delivered')}
              className="flex-1 py-2 bg-emerald-50 hover:bg-emerald-100 text-emerald-700 rounded-lg text-sm font-semibold transition-all cursor-pointer border border-emerald-100"
            >
              Mark Delivered
            </button>
            <button
              onClick={() => setDelayMode(true)}
              className="flex-1 py-2 bg-rose-50 hover:bg-rose-100 text-rose-600 rounded-lg text-sm font-semibold transition-all cursor-pointer border border-rose-100"
            >
              Delay Order
            </button>
          </div>
        </>
      )}

      {/* State 2: No ETA yet — show time picker + Set button */}
      {!hasEta && (
        <>
          <p className="text-xs text-slate-400">Pick a delivery time to notify the customer.</p>
          <div className="flex gap-2">
            <input
              type="time"
              value={etaValue}
              onChange={(event) => onEtaChange(event.target.value)}
              className="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:border-indigo-500"
            />
            <button
              onClick={() => onSaveEta(false)}
              disabled={savingEta}
              className="px-3.5 py-2.5 bg-indigo-600 hover:bg-indigo-700 disabled:bg-indigo-300 text-white rounded-lg text-sm font-semibold transition-all cursor-pointer"
            >
              {savingEta ? <Loader2 size={15} className="animate-spin" /> : 'Set'}
            </button>
          </div>
        </>
      )}

      {/* State 3: Delay mode — show new time picker + Confirm + Cancel */}
      {hasEta && delayMode && (
        <>
          <p className="text-xs text-rose-500 font-medium">Select the new delivery time:</p>
          <div className="flex gap-2">
            <input
              type="time"
              value={etaValue}
              onChange={(event) => onEtaChange(event.target.value)}
              className="w-full px-3 py-2.5 bg-white border border-rose-200 rounded-lg text-sm focus:outline-none focus:border-rose-400"
            />
            <button
              onClick={handleConfirmDelay}
              disabled={savingEta}
              className="px-3.5 py-2.5 bg-rose-600 hover:bg-rose-700 disabled:bg-rose-300 text-white rounded-lg text-sm font-semibold transition-all cursor-pointer whitespace-nowrap"
            >
              {savingEta ? <Loader2 size={15} className="animate-spin" /> : 'Confirm'}
            </button>
          </div>
          <button
            onClick={() => setDelayMode(false)}
            className="text-xs text-slate-400 hover:text-slate-600 cursor-pointer transition-colors"
          >
            Cancel
          </button>
        </>
      )}
    </div>
  );
};

const InfoLine = ({ label, value, strong = false }) => (
  <div>
    <div className="text-[11px] uppercase tracking-wide text-slate-400 font-bold">{label}</div>
    <div className={`text-slate-700 ${strong ? 'font-bold' : 'font-medium'}`}>{value}</div>
  </div>
);

export default OrderManager;
