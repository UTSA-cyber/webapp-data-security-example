# WEBAPP Data Security Example

## Purpose

An example web application that demonstrates data security/access based on their role assigned to them by the system (default) or administrator. The purpose of this project is educational as to show how tuple-level and table-level data security should be used to restrict access to data based on the user's permissions.

## Background

In previous projects, I used Hasura as middleware between the web application and PostgreSQL database for data security. Roles: administrator, student, instructor, and developer were created and tuple-level security was implemented on each table and view.

## Tech Stack

- PostgreSQL database
- Supabase (database & middleware)
- Typescript
- ReactJS
- Radix-UI
- Vite
- Tailwind-CSS

## Proposed Dataset

- Roles: student, instructor, supervisor, adminstrator
- Tables:
    - Users - user information to include name, email
    - Roles - see above
    - Memberships - mapping between users and roles
    - Courses - courses to be taught to include course number, description
    - Classrooms - classroom information including site, course and instructor information
    - Enrollments - mapping of students to classrooms and courses
    - Sites - institution information including name, address

## Proposed Views

- Student should see courses they are enrolled in and their information
- Instructor should see classrooms they oversee
- Supervisors should see sites, classrooms, and teachers they oversee
- Administrator should have access to everything

## Invalid Views

- Student view should have a pane that attempts to access classrooms for a teacher
- Instructor view should have a pane that attepts to access sites

## Additional Information

- Project must have a docker compose and nomad job
- Project must use modern authentication
    - Must consider SSO authentication
- Project must use accepted coding practices (e.g. linting, prettier)
- Project must be simple and elegant
- Ask questions till you reach clarity