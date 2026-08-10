# JavaScript / TypeScript — Patterns

Day-to-day patterns for React (Vite), Next.js (App Router), and NestJS
backends. The index ([`AGENTS.md`](./AGENTS.md)) sets build system,
project structure, and CI gates; this file is the how.

## React Patterns

### Component Structure

One directory per component, with a barrel `index.js`:

```jsx
// components/auth/LoginPage/LoginPage.js
export default function LoginPage() { ... }

// components/auth/LoginPage/index.js
export { default } from './LoginPage'
```

### Barrel Exports

```jsx
// components/auth/index.js
export { default as AuthButton } from './AuthButton'
export { default as LoginPage } from './LoginPage'
export { default as PrivateRoute } from './PrivateRoute'
```

### Private Route

```jsx
function PrivateRoute({ children }) {
    const isLogged = useSelector(state => state.auth.isLogged)
    return isLogged ? children : <Navigate to="/login" />
}
```

### Custom Hook: useForm

```javascript
function useForm(initialFormValue) {
    const [formValue, setFormValue] = useState(initialFormValue)

    const handleChange = (event) => { /* type-aware: checkbox, number, file, text */ }
    const handleSubmit = (onSubmit) => (event) => { event.preventDefault(); onSubmit(formValue) }
    const validate = (validations) => validations.every(fn => fn(formValue))

    return { formValue, setFormValue, handleChange, handleSubmit, validate }
}
```

## Redux (if used)

### Action Type Triplets

Every async action follows the REQUEST / SUCCESS / FAILURE pattern:

```javascript
export const FETCH_USER_REQUEST = 'FETCH_USER_REQUEST'
export const FETCH_USER_SUCCESS = 'FETCH_USER_SUCCESS'
export const FETCH_USER_FAILURE = 'FETCH_USER_FAILURE'
```

### Thunk Pattern

```javascript
export const fetchUser = (userId) => async (dispatch, getState, { api }) => {
    dispatch({ type: FETCH_USER_REQUEST })
    try {
        const user = await api.users.getUser(userId)
        dispatch({ type: FETCH_USER_SUCCESS, payload: user })
    } catch (error) {
        dispatch({ type: FETCH_USER_FAILURE, payload: error })
    }
}
```

### Cache Guard in Thunks

```javascript
export const fetchAdverts = () => async (dispatch, getState, { api }) => {
    const state = getState()
    if (state.adverts.loaded) return  // Already loaded
    dispatch({ type: FETCH_ADVERTS_REQUEST })
    ...
}
```

## API Client Pattern

```javascript
// api/client.js
import axios from 'axios'

const client = axios.create({ baseURL: process.env.REACT_APP_API_BASE_URL })
client.interceptors.response.use(
    response => response.data,
    error => Promise.reject(error.response?.data ?? error)
)

export default client

// api/adverts.js
import client from './client'
export const getAdverts = (filters) => client.get('/api/v1/adverts', { params: filters })

// api/index.js
export * as adverts from './adverts'
export * as auth from './auth'
```

## Next.js (App Router) Patterns

### Project Structure

```
src/
├── app/                          # App Router pages
│   ├── layout.tsx                # Root layout (html, body)
│   ├── page.tsx                  # Home page (/)
│   ├── loading.tsx               # Suspense fallback UI
│   ├── error.tsx                 # Error boundary (client component)
│   ├── not-found.tsx             # 404 UI
│   ├── (marketing)/              # Route group
│   │   ├── layout.tsx
│   │   ├── page.tsx
│   │   └── pricing/page.tsx
│   ├── (auth)/
│   │   ├── login/page.tsx
│   │   └── register/page.tsx
│   ├── dashboard/                # Protected routes
│   │   ├── layout.tsx
│   │   ├── page.tsx
│   │   ├── settings/page.tsx
│   │   └── users/
│   │       ├── page.tsx
│   │       └── [id]/page.tsx     # Dynamic segment
│   └── api/                      # Route handlers
│       ├── auth/
│       │   └── [...nextauth]/route.ts
│       └── webhooks/
│           └── stripe/route.ts
├── components/
│   ├── ui/                       # Base UI (Button, Input, Card)
│   ├── layout/                   # Header, Footer, Sidebar
│   ├── forms/                    # Form components
│   └── providers.tsx             # Client wrappers (ThemeProvider, SessionProvider)
├── lib/                          # Server-safe utilities
│   ├── db.ts                     # Prisma / Drizzle client
│   ├── auth.ts                   # Auth helpers
│   ├── api.ts                    # Fetch wrappers
│   └── utils.ts                  # cn(), formatters
├── actions/                      # Server Actions (mutations)
│   ├── auth.ts
│   └── users.ts
├── hooks/                        # Client-only hooks
├── types/
├── styles/globals.css
├── public/
│   ├── images/
│   └── fonts/
├── middleware.ts                  # Auth, i18n, redirects
└── next.config.ts
```

### Server Components (Default)

Components are server components by default. Add `'use client'` only for interactivity.

```tsx
// app/dashboard/page.tsx — Server Component
import { db } from '@/lib/db'
import { UserList } from './user-list'

export default async function DashboardPage() {
  const users = await db.user.findMany()
  return <UserList users={users} />
}
```

```tsx
// components/user-list.tsx — Client Component
'use client'

import { useState } from 'react'

export function UserList({ users }: { users: User[] }) {
  const [filter, setFilter] = useState('')
  const filtered = users.filter(u => u.name.includes(filter))

  return (
    <div>
      <input onChange={e => setFilter(e.target.value)} />
      {filtered.map(u => <div key={u.id}>{u.name}</div>)}
    </div>
  )
}
```

### Server Actions (Mutations)

Replace REST endpoints for form submissions. Direct DB access, no API boilerplate.

```tsx
// actions/users.ts
'use server'

import { db } from '@/lib/db'
import { revalidatePath } from 'next/cache'

export async function createUser(formData: FormData) {
  const name = formData.get('name') as string
  const email = formData.get('email') as string

  const user = await db.user.create({ data: { name, email } })
  revalidatePath('/dashboard/users')
  return { ok: true, id: user.id }
}
```

```tsx
// app/dashboard/users/page.tsx
export default function UsersPage() {
  return (
    <form action={createUser}>
      <input name="name" required />
      <input name="email" type="email" required />
      <button type="submit">Create</button>
    </form>
  )
}
```

### Route Handlers

For API endpoints consumed by external clients or when Server Actions aren't enough:

```tsx
// app/api/users/route.ts
import { db } from '@/lib/db'

export async function GET() {
  const users = await db.user.findMany()
  return Response.json(users)
}

export async function POST(request: Request) {
  const body = await request.json()
  const user = await db.user.create({ data: body })
  return Response.json(user, { status: 201 })
}
```

### Data Fetching & Caching

Use Next.js `fetch` extensions for cache control:

```tsx
// Static — build once, never revalidate
const staticData = await fetch(url, { cache: 'force-cache' })

// Dynamic — every request
const liveData = await fetch(url, { cache: 'no-store' })

// ISR — revalidate periodically
const data = await fetch(url, { next: { revalidate: 3600 } })

// Deduplicated — same fetch in parallel components
const user = await fetch(`/api/users/${id}`) // auto-deduped
```

### Metadata API

```tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Dashboard — MyApp',
  description: 'User dashboard',
}

// Per-page dynamic
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const user = await getUser(params.id)
  return { title: `${user.name} — Dashboard` }
}
```

### Auth (NextAuth.js / Auth.js)

```tsx
// app/api/auth/[...nextauth]/route.ts
import NextAuth from 'next-auth'
import { authOptions } from '@/lib/auth'
const handler = NextAuth(authOptions)
export { handler as GET, handler as POST }

// middleware.ts — protect routes
export { default } from 'next-auth/middleware'
export const config = { matcher: ['/dashboard/:path*'] }
```

### Image Optimization

```tsx
import Image from 'next/image'

<Image
  src="/hero.jpg"
  alt="Hero"
  width={1200}
  height={600}
  priority               // LCP image
  placeholder="blur"
  blurDataURL="data:image/webp;base64,..."
/>
```

### Styling (Tailwind CSS by default)

```tsx
import { cn } from '@/lib/utils'

export function Button({ variant = 'primary', ...props }: ButtonProps) {
  return (
    <button
      className={cn(
        'rounded-lg px-4 py-2 font-medium transition-colors',
        variant === 'primary' && 'bg-blue-600 text-white hover:bg-blue-700',
        variant === 'ghost' && 'text-gray-600 hover:bg-gray-100'
      )}
      {...props}
    />
  )
}
```

### When to Use Next.js API Routes vs NestJS

| Use Case | Pick |
|----------|------|
| Simple CRUD, form handling, SSR page | Next.js API routes + Server Actions |
| Complex business logic, multiple consumers | NestJS as separate backend |
| Existing backend already exists | NestJS (call from Server Components) |
| External API consumed by mobile + web | NestJS |

## NestJS Backend Patterns

### Module Structure

Each feature is a NestJS module. Modules register their controllers, services, and imports.

```typescript
@Module({
  imports: [TypeOrmModule.forFeature([User]), forwardRef(() => AuthModule)],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
```

### Controllers

Controllers use decorators for routing, validation, and swagger.

```typescript
@Controller('v1/users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get(':id')
  @HttpCode(HttpStatus.OK)
  async findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.usersService.findById(id)
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(@Body(new ValidationPipe()) dto: CreateUserDto) {
    return this.usersService.create(dto)
  }
}
```

### Services

Business logic in injectable services. No HTTP concerns leak into services.

```typescript
@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly repo: Repository<User>,
  ) {}

  async findById(id: string): Promise<User> {
    const user = await this.repo.findOneBy({ id })
    if (!user) throw new NotFoundException(`User ${id} not found`)
    return user
  }
}
```

### DTO Validation

Use `class-validator` + `class-transformer` decorators on DTOs.

```typescript
export class CreateUserDto {
  @IsEmail()
  @IsNotEmpty()
  email: string

  @IsString()
  @MinLength(8)
  @MaxLength(64)
  password: string

  @IsOptional()
  @IsString()
  displayName?: string
}
```

### Error Handling: Result Types

Prefer discriminated union Result types for expected failures. Throw only for truly exceptional conditions.

```typescript
type Result<T, E> =
  | { ok: true; value: T }
  | { ok: false; error: E }

type CreateUserError = 'EMAIL_TAKEN' | 'INVALID_EMAIL'

// Service returns Result, never throws for expected failures
class UserService {
  async createUser(dto: CreateUserDto): Promise<Result<User, CreateUserError>> {
    const exists = await this.emailRepo.exists(dto.email)
    if (exists) return { ok: false, error: 'EMAIL_TAKEN' }
    const user = await this.userRepo.save(dto)
    return { ok: true, value: user }
  }
}

// Controller maps Result to HTTP
@Post()
async createUser(@Body() dto: CreateUserDto) {
  const result = await this.userService.createUser(dto)
  if (!result.ok) {
    switch (result.error) {
      case 'EMAIL_TAKEN': throw new ConflictException('Email already in use')
      case 'INVALID_EMAIL': throw new BadRequestException('Invalid email format')
    }
  }
  return { statusCode: 201, ...result.value }
}
```

### Global Exception Filter

A single exception filter at the app boundary returns structured JSON errors. Only catches truly exceptional conditions — expected failures are handled via Result types in controllers.

```typescript
@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp()
    const response = ctx.getResponse<Response>()

    const status = exception instanceof HttpException
      ? exception.getStatus()
      : HttpStatus.INTERNAL_SERVER_ERROR

    const body: ExceptionResponse = {
      statusCode: status,
      errorCode: status === 500 ? 'INTERNAL_ERROR' : 'APPLICATION_ERROR',
      description: exception instanceof HttpException
        ? exception.message : 'Internal server error',
    }

    response.status(status).json(body)
  }
}
```
