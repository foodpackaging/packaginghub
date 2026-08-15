import { useState, useEffect } from 'react';
import { api } from './apiClient';
import Login from './components/Login';
import AddProduct from './components/AddProduct';
import Inventory from './components/Inventory';
import CategoryManager from './components/CategoryManager';
import BrandManager from './components/BrandManager';
import BannerManager from './components/BannerManager';
import CouponManager from './components/CouponManager';
import FilterManager from './components/FilterManager';
import OrderManager from './components/OrderManager';
import CustomerManager from './components/CustomerManager';
import ReturnManager from './components/ReturnManager';
import { LayoutDashboard, LogOut, PackagePlus, Tags, Ticket, Image as ImageIcon, SlidersHorizontal, Bookmark, ShoppingBag, Users, Menu, X, RotateCcw } from 'lucide-react';

function App() {
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [authChecked, setAuthChecked] = useState(false);
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [activeTab, setActiveTab] = useState(() => {
    return localStorage.getItem('adminActiveTab') || 'inventory';
  });
  const [editingProduct, setEditingProduct] = useState(null);

  useEffect(() => {
    api.get('/auth/me')
      .then(() => setIsLoggedIn(true))
      .catch(() => setIsLoggedIn(false))
      .finally(() => setAuthChecked(true));
  }, []);

  const handleLogin = () => {
    setIsLoggedIn(true);
  };

  const handleLogout = async () => {
    try {
      await api.post('/auth/admin/logout');
    } catch (err) {
      console.error('Logout request failed:', err);
    }
    setIsLoggedIn(false);
    localStorage.removeItem('adminActiveTab');
  };

  const handleEdit = (product) => {
    setEditingProduct(product);
    setActiveTab('add');
    localStorage.setItem('adminActiveTab', 'add');
  };

  const handleCancelEdit = () => {
    setEditingProduct(null);
    setActiveTab('inventory');
    localStorage.setItem('adminActiveTab', 'inventory');
  };

  const changeTab = (tabId) => {
    setActiveTab(tabId);
    localStorage.setItem('adminActiveTab', tabId);
    setEditingProduct(null);
    setIsMobileMenuOpen(false);
  };

  if (!authChecked) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-white text-slate-400 text-sm font-sans">
        Loading...
      </div>
    );
  }

  if (!isLoggedIn) {
    return <Login onLogin={handleLogin} />;
  }

  return (
    <div className="min-h-screen bg-slate-50 text-slate-800 flex font-sans">
      {/* Mobile Sidebar Overlay */}
      {isMobileMenuOpen && (
        <div 
          className="fixed inset-0 bg-slate-900/50 z-40 md:hidden backdrop-blur-sm transition-opacity" 
          onClick={() => setIsMobileMenuOpen(false)} 
        />
      )}

      {/* Sidebar */}
      <div className={`w-64 bg-white border-r border-slate-100 flex flex-col py-8 px-4 fixed h-full select-none z-50 transition-transform duration-300 ease-in-out ${isMobileMenuOpen ? 'translate-x-0 shadow-2xl' : '-translate-x-full md:translate-x-0'}`}>
        <div className="mb-8 pl-4 flex items-center justify-between">
          <h1 className="text-base font-bold text-slate-900 tracking-tight flex items-center gap-2">
            <span className="w-2 h-2 bg-indigo-600 rounded-full"></span>
            B2B Store Admin
          </h1>
          <button onClick={() => setIsMobileMenuOpen(false)} className="md:hidden p-2 text-slate-400 hover:bg-slate-50 rounded-lg">
            <X size={20} />
          </button>
        </div>
        
        <nav className="flex-1 space-y-1.5 overflow-y-auto pr-2 custom-scrollbar">
          <button 
            onClick={() => changeTab('inventory')}
            className={`w-full flex items-center space-x-3 py-3 px-4 text-sm transition-all rounded-xl cursor-pointer ${
              activeTab === 'inventory' 
                ? 'bg-indigo-50 text-indigo-700 font-semibold' 
                : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900 font-medium'
            }`}
          >
            <LayoutDashboard size={18} className={activeTab === 'inventory' ? 'text-indigo-600' : 'text-slate-400'} />
            <span>Inventory</span>
          </button>
 
          <button 
            onClick={() => changeTab('add')}
            className={`w-full flex items-center space-x-3 py-3 px-4 text-sm transition-all rounded-xl cursor-pointer ${
              activeTab === 'add' && !editingProduct
                ? 'bg-indigo-50 text-indigo-700 font-semibold' 
                : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900 font-medium'
            }`}
          >
            <PackagePlus size={18} className={activeTab === 'add' && !editingProduct ? 'text-indigo-600' : 'text-slate-400'} />
            <span>Add Product</span>
          </button>
 
          <button 
            onClick={() => changeTab('categories')}
            className={`w-full flex items-center space-x-3 py-3 px-4 text-sm transition-all rounded-xl cursor-pointer ${
              activeTab === 'categories' 
                ? 'bg-indigo-50 text-indigo-700 font-semibold' 
                : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900 font-medium'
            }`}
          >
            <Tags size={18} className={activeTab === 'categories' ? 'text-indigo-600' : 'text-slate-400'} />
            <span>Categories</span>
          </button>
 
          <button 
            onClick={() => changeTab('brands')}
            className={`w-full flex items-center space-x-3 py-3 px-4 text-sm transition-all rounded-xl cursor-pointer ${
              activeTab === 'brands' 
                ? 'bg-indigo-50 text-indigo-700 font-semibold' 
                : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900 font-medium'
            }`}
          >
            <Bookmark size={18} className={activeTab === 'brands' ? 'text-indigo-600' : 'text-slate-400'} />
            <span>Brands</span>
          </button>
 
          <button 
            onClick={() => changeTab('filters')}
            className={`w-full flex items-center space-x-3 py-3 px-4 text-sm transition-all rounded-xl cursor-pointer ${
              activeTab === 'filters' 
                ? 'bg-indigo-50 text-indigo-700 font-semibold' 
                : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900 font-medium'
            }`}
          >
            <SlidersHorizontal size={18} className={activeTab === 'filters' ? 'text-indigo-600' : 'text-slate-400'} />
            <span>Filters</span>
          </button>
 
          <button 
            onClick={() => changeTab('banners')}
            className={`w-full flex items-center space-x-3 py-3 px-4 text-sm transition-all rounded-xl cursor-pointer ${
              activeTab === 'banners' 
                ? 'bg-indigo-50 text-indigo-700 font-semibold' 
                : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900 font-medium'
            }`}
          >
            <ImageIcon size={18} className={activeTab === 'banners' ? 'text-indigo-600' : 'text-slate-400'} />
            <span>Banners</span>
          </button>
 
          <button 
            onClick={() => changeTab('orders')}
            className={`w-full flex items-center space-x-3 py-3 px-4 text-sm transition-all rounded-xl cursor-pointer ${
              activeTab === 'orders' 
                ? 'bg-indigo-50 text-indigo-700 font-semibold' 
                : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900 font-medium'
            }`}
          >
            <ShoppingBag size={18} className={activeTab === 'orders' ? 'text-indigo-600' : 'text-slate-400'} />
            <span>Orders</span>
          </button>
 
          <button 
            onClick={() => changeTab('customers')}
            className={`w-full flex items-center space-x-3 py-3 px-4 text-sm transition-all rounded-xl cursor-pointer ${
              activeTab === 'customers' 
                ? 'bg-indigo-50 text-indigo-700 font-semibold' 
                : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900 font-medium'
            }`}
          >
            <Users size={18} className={activeTab === 'customers' ? 'text-indigo-600' : 'text-slate-400'} />
            <span>Customers</span>
          </button>
 
          <button 
            onClick={() => changeTab('coupons')}
            className={`w-full flex items-center space-x-3 py-3 px-4 text-sm transition-all rounded-xl cursor-pointer ${
              activeTab === 'coupons' 
                ? 'bg-indigo-50 text-indigo-700 font-semibold' 
                : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900 font-medium'
            }`}
          >
            <Ticket size={18} className={activeTab === 'coupons' ? 'text-indigo-600' : 'text-slate-400'} />
            <span>Coupons</span>
          </button>

          <button 
            onClick={() => changeTab('returns')}
            className={`w-full flex items-center space-x-3 py-3 px-4 text-sm transition-all rounded-xl cursor-pointer ${
              activeTab === 'returns' 
                ? 'bg-indigo-50 text-indigo-700 font-semibold' 
                : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900 font-medium'
            }`}
          >
            <RotateCcw size={18} className={activeTab === 'returns' ? 'text-indigo-600' : 'text-slate-400'} />
            <span>Returns</span>
          </button>
        </nav>
 
        <div className="pt-4 mt-2 border-t border-slate-100">
          <button 
            onClick={handleLogout}
            className="w-full flex items-center space-x-3 py-3 px-4 text-sm text-slate-500 hover:bg-rose-50 hover:text-rose-600 rounded-xl transition-colors font-medium cursor-pointer"
          >
            <LogOut size={18} />
            <span>Log Out</span>
          </button>
        </div>
      </div>
 
      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0 md:ml-64 transition-all duration-300">
        
        {/* Mobile Header Topbar */}
        <div className="md:hidden bg-white/80 backdrop-blur-md border-b border-slate-100 p-4 flex items-center justify-between sticky top-0 z-30">
          <div className="flex items-center gap-3">
            <button onClick={() => setIsMobileMenuOpen(true)} className="p-2 -ml-2 text-slate-600 hover:bg-slate-100 rounded-lg cursor-pointer">
              <Menu size={20} />
            </button>
            <h1 className="text-sm font-bold text-slate-900 flex items-center gap-2">
              <span className="w-1.5 h-1.5 bg-indigo-600 rounded-full"></span>
              Admin
            </h1>
          </div>
        </div>

        {/* Content Container */}
        <div className="p-4 sm:p-6 lg:p-10 bg-slate-50 flex-1 overflow-x-hidden">
          <div className="w-full max-w-6xl mx-auto">
            {activeTab === 'inventory' ? (
              <Inventory onEdit={handleEdit} />
            ) : activeTab === 'add' ? (
              <AddProduct 
                editProduct={editingProduct} 
                onCancel={handleCancelEdit} 
              />
            ) : activeTab === 'categories' ? (
              <CategoryManager setActiveTab={setActiveTab} />
            ) : activeTab === 'brands' ? (
              <BrandManager setActiveTab={setActiveTab} />
            ) : activeTab === 'filters' ? (
              <FilterManager />
            ) : activeTab === 'banners' ? (
              <BannerManager />
            ) : activeTab === 'orders' ? (
              <OrderManager />
            ) : activeTab === 'customers' ? (
              <CustomerManager />
            ) : activeTab === 'returns' ? (
              <ReturnManager />
            ) : (
              <CouponManager />
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
