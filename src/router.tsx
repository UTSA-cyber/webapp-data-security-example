import { createBrowserRouter } from 'react-router-dom';
import ProtectedLayout from './auth/ProtectedLayout';
import LoginRedirect from './auth/LoginRedirect';
import HomePage from './pages/HomePage';
import StudentPage from './pages/StudentPage';
import InstructorPage from './pages/InstructorPage';
import SupervisorPage from './pages/SupervisorPage';
import AdminPage from './pages/AdminPage';

export const router = createBrowserRouter([
  { path: '/login', Component: LoginRedirect },
  {
    path: '/',
    Component: ProtectedLayout,
    children: [
      { index: true, Component: HomePage },
      { path: 'student', Component: StudentPage },
      { path: 'instructor', Component: InstructorPage },
      { path: 'supervisor', Component: SupervisorPage },
      { path: 'admin', Component: AdminPage },
    ],
  },
]);
