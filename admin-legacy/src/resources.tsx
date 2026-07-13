import {
  BooleanField,
  BooleanInput,
  Create,
  Datagrid,
  Edit,
  List,
  NumberField,
  NumberInput,
  ReferenceField,
  ReferenceInput,
  SelectInput,
  SimpleForm,
  TextField,
  TextInput,
} from 'react-admin';

export const BranchList = () => (
  <List>
    <Datagrid rowClick="edit">
      <TextField source="name" />
      <TextField source="address" />
      <TextField source="hours" />
      <BooleanField source="is_open" />
    </Datagrid>
  </List>
);

const BranchForm = () => (
  <SimpleForm>
    <TextInput source="name" fullWidth />
    <TextInput source="address" fullWidth />
    <TextInput source="phone" />
    <TextInput source="hours" />
    <TextInput source="two_gis_url" fullWidth />
    <TextInput source="google_maps_url" fullWidth />
    <BooleanInput source="is_open" defaultValue />
    <BooleanInput source="is_active" defaultValue />
  </SimpleForm>
);

export const BranchEdit = () => <Edit><BranchForm /></Edit>;
export const BranchCreate = () => <Create><BranchForm /></Create>;

export const CategoryList = () => (
  <List>
    <Datagrid rowClick="edit">
      <TextField source="name" />
      <NumberField source="position" />
      <BooleanField source="is_active" />
    </Datagrid>
  </List>
);

const CategoryForm = () => (
  <SimpleForm>
    <TextInput source="name" />
    <NumberInput source="position" />
    <BooleanInput source="is_active" defaultValue />
  </SimpleForm>
);

export const CategoryEdit = () => <Edit><CategoryForm /></Edit>;
export const CategoryCreate = () => <Create><CategoryForm /></Create>;

export const ProductList = () => (
  <List>
    <Datagrid rowClick="edit">
      <TextField source="name" />
      <ReferenceField source="category_id" reference="categories" />
      <NumberField source="base_price" />
      <TextField source="badge" />
      <BooleanField source="is_seasonal" />
      <BooleanField source="is_active" />
    </Datagrid>
  </List>
);

const ProductForm = () => (
  <SimpleForm>
    <ReferenceInput source="category_id" reference="categories">
      <SelectInput optionText="name" />
    </ReferenceInput>
    <TextInput source="name" fullWidth />
    <TextInput source="description" fullWidth multiline />
    <NumberInput source="base_price" />
    <TextInput source="image_url" fullWidth />
    <TextInput source="badge" />
    <BooleanInput source="is_seasonal" />
    <BooleanInput source="is_active" defaultValue />
  </SimpleForm>
);

export const ProductEdit = () => <Edit><ProductForm /></Edit>;
export const ProductCreate = () => <Create><ProductForm /></Create>;

export const OrderList = () => (
  <List>
    <Datagrid rowClick="edit">
      <TextField source="id" />
      <TextField source="type" />
      <TextField source="status" />
      <TextField source="payment_status" />
      <NumberField source="total_amount" />
      <TextField source="ready_time" />
    </Datagrid>
  </List>
);

export const OrderEdit = () => (
  <Edit>
    <SimpleForm>
      <SelectInput
        source="status"
        choices={[
          { id: 'accepted', name: 'Принят' },
          { id: 'preparing', name: 'Готовится' },
          { id: 'ready', name: 'Готов к выдаче' },
          { id: 'completed', name: 'Завершен' },
          { id: 'cancelled', name: 'Отменен' },
        ]}
      />
      <SelectInput
        source="payment_status"
        choices={[
          { id: 'pending', name: 'Ожидает' },
          { id: 'paid', name: 'Оплачен' },
          { id: 'refunded', name: 'Возврат' },
        ]}
      />
      <TextInput source="ready_time" />
      <TextInput source="comment" fullWidth multiline />
    </SimpleForm>
  </Edit>
);

export const UserList = () => (
  <List>
    <Datagrid rowClick="edit">
      <TextField source="name" />
      <TextField source="email" />
      <TextField source="phone" />
      <TextField source="role_code" />
      <TextField source="referral_code" />
      <BooleanField source="is_active" />
    </Datagrid>
  </List>
);

export const UserEdit = () => (
  <Edit>
    <SimpleForm>
      <TextInput source="name" />
      <TextInput source="email" />
      <TextInput source="phone" />
      <SelectInput
        source="role_code"
        choices={[
          { id: 'owner', name: 'Owner' },
          { id: 'branch_manager', name: 'Branch Manager' },
          { id: 'staff', name: 'Staff' },
          { id: 'customer', name: 'Customer' },
        ]}
      />
      <BooleanInput source="is_active" />
    </SimpleForm>
  </Edit>
);

export const PromoList = () => (
  <List>
    <Datagrid rowClick="edit">
      <TextField source="code" />
      <TextField source="discount_type" />
      <NumberField source="amount" />
      <NumberField source="uses_count" />
      <NumberField source="max_uses" />
      <BooleanField source="is_active" />
    </Datagrid>
  </List>
);

const PromoForm = () => (
  <SimpleForm>
    <TextInput source="code" />
    <SelectInput source="discount_type" choices={[{ id: 'percent', name: 'Процент' }, { id: 'fixed', name: 'Фикс' }]} />
    <NumberInput source="amount" />
    <NumberInput source="max_uses" />
    <BooleanInput source="is_active" defaultValue />
  </SimpleForm>
);

export const PromoEdit = () => <Edit><PromoForm /></Edit>;
export const PromoCreate = () => <Create><PromoForm /></Create>;

export const PromotionList = () => (
  <List>
    <Datagrid rowClick="edit">
      <TextField source="title" />
      <TextField source="kind" />
      <BooleanField source="is_active" />
    </Datagrid>
  </List>
);

const PromotionForm = () => (
  <SimpleForm>
    <TextInput source="title" fullWidth />
    <TextInput source="description" fullWidth multiline />
    <TextInput source="kind" />
    <BooleanInput source="is_active" defaultValue />
  </SimpleForm>
);

export const PromotionEdit = () => <Edit><PromotionForm /></Edit>;
export const PromotionCreate = () => <Create><PromotionForm /></Create>;

export const SimpleListOnly = () => (
  <List>
    <Datagrid>
      <TextField source="id" />
      <TextField source="name" />
      <TextField source="status" />
      <TextField source="created_at" />
    </Datagrid>
  </List>
);
