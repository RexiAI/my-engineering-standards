# JavaScript / TypeScript Standards

## Build System

- **Runtime**: Node.js 22+.
- **Package manager**: npm.
- **Frontend**: React 17+ with Create React App or Vite.
- **Backend**: Express 4.x with Mongoose (MongoDB) or Sequelize/TypeORM (SQL).

## Commands

| Command | What it does |
|---|---|
| `npm start` | Start dev server (React: react-scripts, Express: nodemon) |
| `npm run build` | Production build |
| `npm test` | Run test suite |
| `npm run lint` | Run ESLint |
| `npm run format` | Run Prettier |

## Project Structure

### Express Backend

```
src/
├── app.js                   # Express app setup
├── bin/www                  # HTTP server entry
├── lib/                     # External connection helpers (mongoose, email, etc.)
├── models/                  # Mongoose/TypeORM models
├── routes/
│   ├── api/
│   │   ├── advertisements.js
│   │   └── auth.js
│   └── index.js
├── controllers/             # Route handler logic
├── services/                # Business logic
├── utils/                   # Constants, helper functions
├── DB/                      # Database seed/migration scripts
├── tests/                   # Test files
├── public/                  # Static files
└── locales/                 # i18n translation files
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

## Express Backend Patterns

### Error Handling

```javascript
// utils/errors.js
class AppError extends Error {
    constructor(message, statusCode, errorCode) {
        super(message)
        this.statusCode = statusCode
        this.errorCode = errorCode
    }
}

// app.js - Error middleware
app.use((err, req, res, next) => {
    if (req.isAPIRequest()) {
        res.status(err.statusCode || 500).json({
            errorCode: err.errorCode || 'INTERNAL_ERROR',
            description: err.message || 'Internal server error',
        })
    } else {
        next(err)
    }
})
```

### API Route Versioning

```javascript
const VERSION_1 = 'v1'
router.use(`/api/${VERSION_1}/adverts`, advertisementRoutes)
router.use(`/api/${VERSION_1}/users`, userRoutes)
```

## Testing

| Layer | Framework | Tools |
|---|---|---|
| Unit | Jest | React Testing Library, Jest |
| Integration | Jest | Supertest (Express), redux-mock-store |
| Component | Jest | Enzyme or React Testing Library |
| Snapshot | Jest | enzyme-to-json serializer |

Run all tests: `npm test` (or `npm run test -- --coverage` for coverage).

## Linting & Formatting

- **ESLint**: Extends from shared config (see `.eslintrc.js` in this standards repo).
- **Prettier**: Enforced formatting with pre-configured shared config (see `.prettierrc.js`).

Run linting: `npm run lint`
Run formatter: `npm run format`
