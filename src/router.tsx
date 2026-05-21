import { createBrowserRouter } from 'react-router-dom';
import ProtectedLayout from './auth/ProtectedLayout';
import LoginRedirect from './auth/LoginRedirect';
import Dashboard from './pages/Dashboard';

export const router = createBrowserRouter([
  { path: '/login', Component: LoginRedirect },
  {
    path: '/',
    Component: ProtectedLayout,
    children: [{ index: true, Component: Dashboard }],
  },
]);
