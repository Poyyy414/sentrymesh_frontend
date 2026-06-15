
const apiKey = '0487a1e788fda1d85531d3105c5a763d';
const lat = 13.6218;
const lon = 123.1948;
const url = `https://api.openweathermap.org/data/3.0/onecall?lat=${lat}&lon=${lon}&appid=${apiKey}&units=metric`;

console.log(`Testing OpenWeather One Call 3.0 with key: ${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)}`);
console.log(`URL: ${url.replace(apiKey, 'HIDDEN')}`);

fetch(url)
  .then(async response => {
    const data = await response.json();
    if (response.ok) {
      console.log('✅ Success! Weather data received.');
      console.log('Current Temp:', data.current?.temp);
    } else {
      console.log(`❌ Error ${response.status}: ${response.statusText}`);
      console.log('Response body:', JSON.stringify(data, null, 2));
      
      if (response.status === 401) {
        console.log('\nCommon causes for 401 with One Call 3.0:');
        console.log('1. The "One Call by Call" plan is not active (check https://home.openweathermap.org/subscriptions)');
        console.log('2. The key is brand new (can take 2 hours)');
        console.log('3. You are using a key from a different account/plan');
      }
    }
  })
  .catch(err => {
    console.error('Fetch error:', err.message);
  });
