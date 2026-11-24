// Change this message, push to main, and watch the pipeline deploy it.
export const MESSAGE = 'Hello, World!'

export default function App() {
  return (
    <main style={{ fontFamily: 'system-ui, sans-serif', textAlign: 'center', marginTop: '20vh' }}>
      <h1>{MESSAGE}</h1>
      <p>Deployed by GitHub Actions + Argo CD</p>
    </main>
  )
}
