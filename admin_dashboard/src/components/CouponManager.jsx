import React, { useState, useEffect } from 'react';
import { api } from '../apiClient';
import { Ticket, Plus, Trash2, Tag, AlertCircle, Calendar, DollarSign, Percent } from 'lucide-react';

const CouponManager = () => {
  const [coupons, setCoupons] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showAddForm, setShowAddForm] = useState(false);

  const [newCoupon, setNewCoupon] = useState({
    code: '',
    discount_type: 'percent',
    discount_value: 10,
    min_order_amount: 0,
    is_active: true
  });

  const fetchCoupons = async () => {
    setLoading(true);
    try {
      const { coupons: data } = await api.get('/coupons');
      setCoupons(data || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCoupons();
  }, []);

  const handleAddCoupon = async (e) => {
    e.preventDefault();
    try {
      const { coupon } = await api.post('/coupons', { ...newCoupon, code: newCoupon.code.toUpperCase() });
      setCoupons([coupon, ...coupons]);
      setShowAddForm(false);
      setNewCoupon({ code: '', discount_type: 'percent', discount_value: 10, min_order_amount: 0, is_active: true });
    } catch (err) {
      alert('Error adding coupon: ' + err.message);
    }
  };

  const deleteCoupon = async (id) => {
    if (window.confirm('Delete this coupon?')) {
      try {
        await api.delete(`/coupons/${id}`);
        setCoupons(coupons.filter(c => c.id !== id));
      } catch (err) {
        alert(err.message);
      }
    }
  };

  return (
    <div className="w-full space-y-8 font-sans animate-in fade-in duration-500">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-100">
        <div>
          <h2 className="text-xl font-bold text-slate-900 tracking-tight">Coupons & Discounts</h2>
          <p className="text-slate-500 text-sm font-normal">Create and manage promo codes for your store</p>
        </div>
        <button
          onClick={() => setShowAddForm(!showAddForm)}
          className="flex items-center gap-2 self-start md:self-auto bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-2.5 rounded-xl font-semibold transition-all shadow-md shadow-indigo-600/10 text-sm cursor-pointer"
        >
          {showAddForm ? 'Cancel' : <><Plus size={16} /> New Coupon</>}
        </button>
      </div>

      {error && (
        <div className="flex items-center gap-2 bg-rose-50 border border-rose-100 text-rose-600 p-4 rounded-xl text-sm font-normal">
          <AlertCircle size={18} />
          {error}
        </div>
      )}

      {showAddForm && (
        <div className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm animate-in zoom-in-95 duration-200">
          <form onSubmit={handleAddCoupon} className="grid grid-cols-1 md:grid-cols-4 gap-6 items-end">
            <div>
              <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2 pl-1">Coupon Code</label>
              <input
                type="text"
                required
                placeholder="SAVE50"
                value={newCoupon.code}
                onChange={(e) => setNewCoupon({ ...newCoupon, code: e.target.value })}
                className="w-full bg-white border border-slate-200 rounded-xl px-4 py-2.5 text-slate-800 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none font-mono text-sm placeholder-slate-400 font-normal"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2 pl-1">Discount (%)</label>
              <div className="relative">
                <Percent className="absolute left-3 top-3 text-slate-400" size={16} />
                <input
                  type="number"
                  required
                  value={newCoupon.discount_value}
                  onChange={(e) => setNewCoupon({ ...newCoupon, discount_value: parseInt(e.target.value) })}
                  className="w-full bg-white border border-slate-200 rounded-xl pl-9 pr-4 py-2.5 text-slate-800 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none text-sm font-normal"
                />
              </div>
            </div>
            <div>
              <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2 pl-1">Min. Order (₹)</label>
              <div className="relative">
                <span className="absolute left-3 top-2.5 text-slate-400 text-sm font-medium">₹</span>
                <input
                  type="number"
                  required
                  value={newCoupon.min_order_amount}
                  onChange={(e) => setNewCoupon({ ...newCoupon, min_order_amount: parseFloat(e.target.value) })}
                  className="w-full bg-white border border-slate-200 rounded-xl pl-7 pr-4 py-2.5 text-slate-800 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none text-sm font-normal"
                />
              </div>
            </div>
            <button
              type="submit"
              className="bg-indigo-600 text-white py-3 px-6 rounded-xl font-semibold hover:bg-indigo-700 transition-all text-sm cursor-pointer shadow-md shadow-indigo-600/10 h-[42px]"
            >
              Create Coupon
            </button>
          </form>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {coupons.map((coupon) => (
          <div key={coupon.id} className="bg-white border border-slate-200 p-6 rounded-xl hover:border-indigo-500/30 transition-all group relative overflow-hidden">
            <div className="absolute top-3 right-3 opacity-0 group-hover:opacity-100 transition-opacity">
              <button
                onClick={() => deleteCoupon(coupon.id)}
                className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-colors cursor-pointer"
              >
                <Trash2 size={16} />
              </button>
            </div>

            <div className="flex items-start justify-between mb-5">
              <div className="bg-indigo-50 p-3 rounded-xl text-indigo-600">
                <Ticket size={22} />
              </div>
              <div className="text-right">
                <span className="text-2xl font-bold text-slate-900 tracking-tight">
                  {coupon.discount_type === 'percent' ? `${coupon.discount_value}%` : `₹${coupon.discount_value}`}
                </span>
                <p className="text-slate-400 text-[9px] uppercase font-semibold tracking-wider mt-0.5">OFF ANY ORDER</p>
              </div>
            </div>

            <div className="space-y-4">
              <div>
                <div className="text-slate-400 text-[9px] uppercase font-semibold tracking-wider mb-2 pl-1">Promo Code</div>
                <div className="bg-slate-50 border border-slate-200 border-dashed rounded-xl px-4 py-2.5 text-indigo-600 font-mono font-semibold tracking-widest text-center text-sm">
                  {coupon.code}
                </div>
              </div>

              <div className="flex items-center justify-between text-xs pt-2 border-t border-slate-50">
                <div className="flex items-center gap-1 text-slate-500 font-normal">
                  <span>Min Order: <b>₹{coupon.min_order_amount}</b></span>
                </div>
                <div className={`px-2 py-0.5 rounded text-[10px] font-semibold uppercase tracking-wider ${coupon.is_active ? 'bg-emerald-50 text-emerald-600 border border-emerald-100/50' : 'bg-slate-100 text-slate-500'}`}>
                  {coupon.is_active ? 'Active' : 'Inactive'}
                </div>
              </div>
            </div>
          </div>
        ))}

        {coupons.length === 0 && !loading && (
          <div className="col-span-full py-20 text-center bg-white rounded-2xl border border-slate-200 border-dashed">
            <Ticket size={40} className="mx-auto text-slate-300 mb-4 animate-bounce" />
            <p className="text-slate-500 text-sm font-normal">No coupons created yet. Click "New Coupon" to start!</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default CouponManager;
