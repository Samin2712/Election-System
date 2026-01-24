# 🔐 **Admin vs User - Complete Guide**

## 📊 **Understanding the Two Role Systems**

Your application has **TWO separate role concepts**:

---

## 1️⃣ **Organization Roles** (Already Working ✅)

These control what users can do **within a specific organization**.

### **Roles:**

| Role | Icon | Description | Permissions |
|------|------|-------------|-------------|
| **OWNER** | 👑 | Organization creator | Everything in the org |
| **ADMIN** | ⚡ | Organization admin | Manage elections, approve voters |
| **MEMBER** | 👤 | Regular member | View elections, vote |

### **How it Works:**
```
User "John" can be:
├─ OWNER in "University Student Council"
├─ ADMIN in "Computer Science Club"
└─ MEMBER in "Basketball Association"
```

**Current Status:** ✅ **Fully Implemented**
- Visible in UI with role badges
- Stored in `org_members` table
- Changes per organization

---

## 2️⃣ **System Roles** (Need to Implement)

These control what users can do **across the entire system**.

### **Roles:**

| Role | Description | Powers |
|------|-------------|--------|
| **Regular User** | Default | Create orgs, join orgs, vote |
| **System Admin** | Super user | Approve orgs, manage users, system settings |

### **How it Works:**
```
User "Alice" is:
├─ System Admin (can approve organizations)
└─ Also OWNER in her own organization

User "Bob" is:
├─ Regular User (cannot approve organizations)
└─ OWNER in his organization
```

**Current Status:** ⚠️ **Needs Implementation**

---

## 🛠️ **Implementation Options**

### **Option 1: Simple Flag** ⭐ (Recommended)

**Pros:**
- Simple to implement
- Easy to check
- Fast queries

**Implementation:**
```sql
-- Add column to users table
ALTER TABLE users ADD COLUMN is_system_admin BOOLEAN DEFAULT FALSE;

-- Make a user system admin
UPDATE users SET is_system_admin = TRUE WHERE user_id = 1;
```

**Usage in Code:**
```typescript
// Backend
const isAdmin = user.is_system_admin;

// Frontend
const { user } = useAuthStore();
if (user.is_system_admin) {
  // Show admin features
}
```

---

### **Option 2: Separate Table** (More Flexible)

**Pros:**
- Can track who granted admin
- Can track when granted
- Can revoke easily

**Implementation:**
```sql
CREATE TABLE system_admins (
    admin_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(user_id),
    granted_by BIGINT REFERENCES users(user_id),
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);
```

---

## 🚀 **Recommended Approach**

Use **Option 1** (Simple Flag) because:
1. ✅ Easy to implement
2. ✅ Fast to check
3. ✅ Sufficient for most use cases
4. ✅ Can upgrade to Option 2 later if needed

---

## 📋 **Step-by-Step Implementation**

### **Step 1: Run Migration**

```bash
npm run migrate
```

This will apply `014_system_admin_flag.sql` which adds `is_system_admin` to users table.

---

### **Step 2: Make Your First Admin**

**Option A: Using SQL**
```sql
-- Connect to database
psql -U election_user -d election_db

-- Make user with ID 1 a system admin
UPDATE users SET is_system_admin = TRUE WHERE user_id = 1;

-- Or by email
UPDATE users SET is_system_admin = TRUE WHERE email = 'admin@example.com';

-- Verify
SELECT user_id, username, email, is_system_admin FROM users;
```

**Option B: Using API Endpoint** (Create this)
```typescript
// POST /admin/grant-admin
// Body: { user_id: 1 }
// Requires: Current user must be system admin
```

---

### **Step 3: Update Frontend Types**

```typescript
// apps/web/src/types/index.ts
export interface User {
    user_id: number;
    username: string;
    email: string;
    role_id: number;
    is_active: boolean;
    is_system_admin?: boolean;  // ← Add this
}
```

---

### **Step 4: Update Login Response**

```typescript
// apps/api/src/routes/auth.routes.ts
// In login endpoint, include is_system_admin in response

const user = {
    user_id: userData.user_id,
    username: userData.username,
    email: userData.email,
    role_id: userData.role_id,
    is_active: userData.is_active,
    is_system_admin: userData.is_system_admin || false  // ← Add this
};
```

---

### **Step 5: Add Admin UI**

**Show Admin Badge in Header:**
```tsx
// apps/web/src/components/Layout.tsx
const { user } = useAuthStore();

{user?.is_system_admin && (
  <span className="px-2 py-1 bg-red-100 text-red-800 text-xs font-bold rounded">
    🛡️ SYSTEM ADMIN
  </span>
)}
```

**Add Admin Menu:**
```tsx
{user?.is_system_admin && (
  <Link to="/admin" className="nav-link">
    <Shield className="w-4 h-4" />
    <span>Admin Panel</span>
  </Link>
)}
```

---

## 🎯 **Permission Matrix**

### **What System Admins Can Do:**

| Action | Regular User | System Admin |
|--------|--------------|--------------|
| Create organization | ✅ | ✅ |
| Join organization | ✅ | ✅ |
| Vote in elections | ✅ | ✅ |
| **Approve organizations** | ❌ | ✅ |
| **Suspend organizations** | ❌ | ✅ |
| **View all organizations** | ❌ | ✅ |
| **Manage all users** | ❌ | ✅ |
| **View system analytics** | ❌ | ✅ |

### **Organization Roles (Separate):**

| Action | MEMBER | ADMIN | OWNER |
|--------|--------|-------|-------|
| View elections | ✅ | ✅ | ✅ |
| Create election | ❌ | ✅ | ✅ |
| Approve voters | ❌ | ✅ | ✅ |
| Add members | ❌ | ✅ | ✅ |
| Delete organization | ❌ | ❌ | ✅ |

---

## 🔒 **Security Best Practices**

### **1. Protect Admin Endpoints**

```typescript
// Middleware to check system admin
export const requireSystemAdmin = (req, res, next) => {
  if (!req.user?.is_system_admin) {
    return res.status(403).json({ 
      ok: false, 
      error: 'System admin privileges required' 
    });
  }
  next();
};

// Use it
router.post('/admin/approve-org/:id', authMiddleware, requireSystemAdmin, async (req, res) => {
  // Only system admins can access this
});
```

### **2. Protect Admin UI**

```tsx
// apps/web/src/App.tsx
<Route path="/admin" element={
  <RequireSystemAdmin>
    <AdminDashboard />
  </RequireSystemAdmin>
} />

// RequireSystemAdmin component
function RequireSystemAdmin({ children }) {
  const { user } = useAuthStore();
  
  if (!user?.is_system_admin) {
    return <Navigate to="/" replace />;
  }
  
  return children;
}
```

---

## 🎨 **UI Examples**

### **Header with System Admin Badge**

```
┌────────────────────────────────────────────────────┐
│ [Logo] Election System                             │
│                                                     │
│ [🏢 University ▼] [👑 OWNER] [🛡️ SYSTEM ADMIN]    │
│                                          [Profile]  │
└────────────────────────────────────────────────────┘
```

### **Admin Dashboard**

```
┌────────────────────────────────────────────────────┐
│ 🛡️ System Administration                          │
├────────────────────────────────────────────────────┤
│                                                     │
│ Pending Organizations (3)                          │
│ ├─ Computer Science Club     [Approve] [Reject]   │
│ ├─ Basketball Association    [Approve] [Reject]   │
│ └─ Drama Society             [Approve] [Reject]   │
│                                                     │
│ All Organizations (12)                             │
│ All Users (45)                                     │
│ System Analytics                                   │
└────────────────────────────────────────────────────┘
```

---

## 📝 **Quick Reference**

### **Check if User is System Admin**

**Backend:**
```typescript
if (req.user.is_system_admin) {
  // Allow admin action
}
```

**Frontend:**
```typescript
const { user } = useAuthStore();
if (user?.is_system_admin) {
  // Show admin UI
}
```

### **Check Organization Role**

**Frontend:**
```typescript
const { currentOrganizationRole } = useAuthStore();
if (currentOrganizationRole === 'OWNER') {
  // Show owner actions
}
```

---

## 🚀 **Implementation Checklist**

### **Database** ✅
- [x] Create migration 014
- [ ] Run migration
- [ ] Make first user system admin

### **Backend**
- [ ] Update login to return `is_system_admin`
- [ ] Create `requireSystemAdmin` middleware
- [ ] Add admin endpoints (approve org, etc.)

### **Frontend**
- [ ] Update User type
- [ ] Add system admin badge to header
- [ ] Create admin dashboard page
- [ ] Add admin routes
- [ ] Protect admin routes

---

## 🎯 **Next Steps**

1. **Run the migration:**
   ```bash
   npm run migrate
   ```

2. **Make yourself a system admin:**
   ```sql
   UPDATE users SET is_system_admin = TRUE WHERE email = 'your@email.com';
   ```

3. **Update login endpoint** to return `is_system_admin`

4. **Add admin badge** to header

5. **Create admin dashboard** (optional for now)

---

## 💡 **Summary**

**Two Role Systems:**
1. **Organization Roles** (OWNER/ADMIN/MEMBER) - ✅ Already working
2. **System Roles** (Admin/User) - ⚠️ Need to implement

**Recommended:**
- Use simple `is_system_admin` flag
- Run migration 014
- Update login to include flag
- Add admin UI when needed

**The migration file is ready!** Just run `npm run migrate` to apply it. 🚀
