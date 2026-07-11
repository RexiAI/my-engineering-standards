# JavaScript / TypeScript Standards

## Build System

- **Runtime**: Node.js 22+.
- **Package manager**: npm.
- **Frontend**: React 17+ with Create React App or Vite.
- **Backend**: NestJS with TypeORM or Prisma (SQL).

## Commands

| Command | What it does |
|---|---|
| `npm start` | Start dev server (React: vite, NestJS: nest start) |
| `npm run build` | Production build |
| `npm test` | Run test suite |
| `npm run lint` | Run ESLint |
| `npm run format` | Run Prettier |

## Project Structure

### NestJS Backend

```
src/
├── main.ts                  # Entry point (NestFactory.create)
├── app.module.ts            # Root module imports
├── common/                  # Shared guards, filters, pipes, interceptors
│   ├── guards/
│   ├── filters/
│   ├── pipes/
│   └── interceptors/
├── modules/                 # Feature modules
│   ├── auth/
│   │   ├── auth.module.ts
│   │   ├── auth.controller.ts
│   │   ├── auth.service.ts
│   │   ├── dto/             # class-validator DTOs
│   │   └── strategies/      # Passport strategies
│   ├── users/
│   │   ├── users.module.ts
│   │   ├── users.controller.ts
│   │   ├── users.service.ts
│   │   ├── entities/        # TypeORM entities / Prisma schema
│   │   └── dto/
│   └── ...
├── database/                # Migrations, seeds, data sources
├── config/                  # Configuration modules (env, validation)
└── test/                    # E2E test files
```

### React Frontend

```
src/
├── api/
│   ├── client.js            # Axios instance + interceptors
│   ├── auth.js              # Auth API functions
│   ├── adverts.js           # Domain API functions
│   └── index.js             # Barrel export
├── components/
│   ├── auth/
│   │   ├── LoginPage/
│   │   │   ├── LoginPage.js
│   │   │   └── index.js     # export { default } from './LoginPage'
│   │   └── index.js         # Barrel export
│   ├── adverts/
│   │   ├── AdvertsPage/
│   │   │   ├── Advert.js
│   │   │   ├── AdvertsPage.js
│   │   │   └── index.js
│   │   └── index.js
│   └── shared/              # Reusable UI components
├── hooks/
│   └── useForm.js           # Form state + validation hook
├── store/                   # Redux store (if using Redux)
│   ├── index.js             # configureStore
│   ├── actions.js           # Action creators + thunks
│   ├── reducers.js          # Reducers
│   ├── selectors.js         # Selectors
│   └── types.js             # Action type constants
├── utils/
│   ├── storage.js           # localStorage helpers
│   └── utils.js             # General utilities
├── styles/                  # Global CSS
├── translations/            # i18n config and locale files
├── App.js                   # Root component
└── index.js                 # Entry point
```

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

### Global Exception Filter

A single exception filter at the app boundary returns structured JSON errors.

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
      errorCode: exception instanceof ApplicationException
        ? exception.getErrorCode() : 'INTERNAL_ERROR',
      description: exception instanceof HttpException
        ? exception.message : 'Internal server error',
    }

    response.status(status).json(body)
  }
}
```

## Testing

| Layer | Framework | Tools |
|---|---|---|
| Unit | Jest | React Testing Library, Jest |
| Integration | Jest | Supertest (NestJS), redux-mock-store |
| Component | Jest | Enzyme or React Testing Library |
| Snapshot | Jest | enzyme-to-json serializer |

Run all tests: `npm test` (or `npm run test -- --coverage` for coverage).

## Linting & Formatting

- **ESLint**: Extends from shared config (see `.eslintrc.js` in this standards repo).
- **Prettier**: Enforced formatting with pre-configured shared config (see `.prettierrc.js`).

Run linting: `npm run lint`
Run formatter: `npm run format`
