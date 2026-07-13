import React from 'react';
import ReactDOM from 'react-dom/client';
import { Admin, Resource, radiantLightTheme, radiantDarkTheme } from 'react-admin';
import LocalCafeIcon from '@mui/icons-material/LocalCafe';
import StorefrontIcon from '@mui/icons-material/Storefront';
import ReceiptLongIcon from '@mui/icons-material/ReceiptLong';
import PeopleIcon from '@mui/icons-material/People';
import LoyaltyIcon from '@mui/icons-material/Loyalty';
import CampaignIcon from '@mui/icons-material/Campaign';
import SettingsIcon from '@mui/icons-material/Settings';

import { Dashboard } from './screens/Dashboard';
import { LoginPage } from './screens/LoginPage';
import { authProvider } from './providers/authProvider';
import { dataProvider } from './providers/dataProvider';
import {
  BranchCreate,
  BranchEdit,
  BranchList,
  CategoryCreate,
  CategoryEdit,
  CategoryList,
  OrderEdit,
  OrderList,
  ProductCreate,
  ProductEdit,
  ProductList,
  PromoCreate,
  PromoEdit,
  PromoList,
  PromotionCreate,
  PromotionEdit,
  PromotionList,
  SimpleListOnly,
  UserEdit,
  UserList,
} from './resources';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <Admin
      title="SweetTime Admin"
      dataProvider={dataProvider}
      authProvider={authProvider}
      dashboard={Dashboard}
      loginPage={LoginPage}
      theme={radiantLightTheme}
      darkTheme={radiantDarkTheme}
      requireAuth
    >
      <Resource name="orders" list={OrderList} edit={OrderEdit} icon={ReceiptLongIcon} />
      <Resource name="products" list={ProductList} edit={ProductEdit} create={ProductCreate} icon={LocalCafeIcon} />
      <Resource name="categories" list={CategoryList} edit={CategoryEdit} create={CategoryCreate} icon={SettingsIcon} />
      <Resource name="modifier-groups" list={SimpleListOnly} icon={SettingsIcon} />
      <Resource name="modifier-options" list={SimpleListOnly} icon={SettingsIcon} />
      <Resource name="branches" list={BranchList} edit={BranchEdit} create={BranchCreate} icon={StorefrontIcon} />
      <Resource name="users" list={UserList} edit={UserEdit} icon={PeopleIcon} />
      <Resource name="points-ledger" list={SimpleListOnly} icon={LoyaltyIcon} />
      <Resource name="referrals" list={SimpleListOnly} icon={LoyaltyIcon} />
      <Resource name="promo-codes" list={PromoList} edit={PromoEdit} create={PromoCreate} icon={CampaignIcon} />
      <Resource name="promotions" list={PromotionList} edit={PromotionEdit} create={PromotionCreate} icon={CampaignIcon} />
      <Resource name="push-tokens" list={SimpleListOnly} icon={CampaignIcon} />
      <Resource name="recurring-orders" list={SimpleListOnly} icon={ReceiptLongIcon} />
    </Admin>
  </React.StrictMode>,
);
