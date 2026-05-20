import { createBrowserRouter } from 'react-router-dom';
import RootLayout from './layouts/RootLayout';
import HomePage from './pages/HomePage';
import LoginPage from './pages/LoginPage';
import StudentPage from './pages/StudentPage';
import InstructorPage from './pages/InstructorPage';
import SupervisorPage from './pages/SupervisorPage';
import AdminPage from './pages/AdminPage';

export const router = createBrowserRouter([
  {
    path: '/',
    Component: RootLayout,
    children: [
      { index: true, Component: HomePage },
      { path: 'login', Component: LoginPage },
      { path: 'student', Component: StudentPage },
      { path: 'instructor', Component: InstructorPage },
      { path: 'supervisor', Component: SupervisorPage },
      { path: 'admin', Component: AdminPage },
    ],
  },
]);
